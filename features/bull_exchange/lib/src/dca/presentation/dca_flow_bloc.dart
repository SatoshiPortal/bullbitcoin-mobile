import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/dca/presentation/dca_flow.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The calls of the DCA flow, bound to one session.
typedef DcaFlowCalls = ({
  Future<ExchangeRead<DcaContext>> Function() loadContext,
  Future<ExchangeRead<double>> Function(Market market) rate,
  Future<ExchangeRead<DefaultWallets>> Function() defaultWallets,
  Future<ConfirmAnswered<DcaPlan, DcaPlan>> Function(
    ConfirmSend<DcaPlan> effect,
  )
  create,
  Future<ExchangeRead<UserSummary>> Function() readSummary,
  Future<void> Function() activate,
});

DcaFlowCalls dcaFlowCallsOf(Exchange exchange, ExchangeSession session) {
  final orders = exchange.orders(session.environment);
  return (
    loadContext: () async {
      final summary = readOfResult(
        await exchange.getUserSummary(session.environment),
      );
      final wallets = readOfResult(await exchange.getDefaultWallets());
      // A journal that can't be read leaves no entry to start from; the
      // write gate then refuses the create itself (JournalUnreadable).
      final entries = switch (await exchange.openUnknownWrites()) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      return switch ((summary, wallets)) {
        (ReadGot(value: final summary), ReadGot(value: final wallets)) =>
          ReadGot(
            DcaContext(
              summary: summary,
              defaultWallets: wallets,
              openEntries: entries,
            ),
          ),
        (ReadSessionRejected(:final why), _) ||
        (_, ReadSessionRejected(:final why)) => ReadSessionRejected(why),
        (ReadUnreachable(:final reason, :final isNetwork), _) ||
        (
          _,
          ReadUnreachable(:final reason, :final isNetwork),
        ) => ReadUnreachable(reason, isNetwork: isNetwork),
        (ReadMalformed(:final reason), _) ||
        (_, ReadMalformed(:final reason)) => ReadMalformed(reason),
        (ReadMissing(), _) || (_, ReadMissing()) => const ReadMissing(),
      };
    },
    rate: (market) async =>
        switch (await exchange.limitOrders.getRate(market.currency.code)) {
          Ok(:final value) => ReadGot(value.indexPrice),
          Err(:final failure) => readOfExchangeFailure(failure),
        },
    defaultWallets: () async =>
        readOfResult(await exchange.getDefaultWallets()),
    create: (effect) => runServerConfirm(
      gate: exchange.writeGate,
      session: session,
      policy: dcaConfirmPolicy,
      effect: effect,
      confirm: (plan) async => switch (await orders.createDca(
        amount: plan.fiat,
        currency: plan.currency,
        frequency: plan.frequency,
        network: plan.payout.network,
        address: plan.payout.address,
      )) {
        WriteDone() => WriteDone(plan),
        WriteRefused(:final reason) => WriteRefused(reason),
        WriteNotSent(:final reason) => WriteNotSent(reason),
        WriteSessionRejected() => const WriteSessionRejected(),
        WriteOutcomeUnknown(:final reason) => WriteOutcomeUnknown(reason),
      },
    ),
    readSummary: () async =>
        readOfResult(await exchange.getUserSummary(session.environment)),
    activate: () async {
      // The recurring buy exists either way; the preference is best-effort.
      final enabled = await exchange.updateCurrentPreferences(
        const ExchangePreferencesPatch(dcaEnabled: true),
      );
      if (enabled case Err(:final failure)) {
        log.warning(
          'DCA created but enabling the preference failed',
          error: failure.runtimeType,
        );
      }
    },
  );
}

/// Shell of [transitionDcaFlow]: applies events one at a time, emits the
/// new state and runs its effects, each answer tagged with its attempt or
/// ticket.
class DcaFlowBloc extends Bloc<DcaFlowEvent, DcaFlowState> {
  DcaFlowBloc({
    required DcaFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         dcaFlowStart(session),
       );

  DcaFlowBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    DcaFlowNext start,
  ) : super(start.state) {
    on<DcaFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(DcaSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final DcaFlowCalls? _calls;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(DcaFlowEvent event, Emitter<DcaFlowState> emit) {
    final before = state;
    final next = transitionDcaFlow(before, event);
    if (identical(next.state, before) && next.effects.isEmpty) return;
    if (!identical(next.state, before)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<DcaFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case DcaLoadContext(:final attempt):
          _answer(
            calls.loadContext().then((r) => DcaContextLoaded(attempt, r)),
          );
        case DcaReloadForDetour():
          _answer(calls.loadContext().then(DcaDetourLoaded.new));
        case DcaFetchRate(:final market):
          _answer(
            calls
                .rate(market)
                .then((r) => DcaAmountChanged(AmountRateArrived(market, r))),
          );
        case DcaLoadDefaultWallets(:final ticket):
          _answer(
            calls.defaultWallets().then(
              (r) => DcaDefaultWalletsLoaded(ticket, r),
            ),
          );
        case DcaConfirmEffect(effect: final ConfirmSend<DcaPlan> send):
          _answer(calls.create(send).then(DcaConfirmChanged.new));
        case DcaConfirmEffect(
          effect: ConfirmVerify(:final target, :final attempt),
        ):
          _answer(
            calls.readSummary().then(
              (read) => DcaConfirmChanged(
                ConfirmVerified(attempt, dcaConfirmCheck(target, read)),
              ),
            ),
          );
        case DcaActivated():
          unawaited(calls.activate());
      }
    }
  }

  void _answer(Future<DcaFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    await _access.cancel();
    return super.close();
  }
}
