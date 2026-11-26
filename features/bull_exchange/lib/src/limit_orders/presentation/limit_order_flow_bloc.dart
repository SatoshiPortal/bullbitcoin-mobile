import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:secrets/secrets.dart';

/// The exchange and wallet calls of the limit-order flow, bound to one
/// session.
typedef LimitFlowCalls = ({
  Future<ExchangeRead<LimitOrderContext>> Function() loadContext,
  Future<ExchangeRead<LimitOrderRate>> Function(Market market) rate,
  Future<Result<Destination, Failure>> Function(DestinationOptionAppWallet)
  receiveAddress,
  Future<Result<Destination, Failure>> Function(String text) lightningAddress,
  Future<ConfirmAnswered<LimitOrderRequest, LimitOrder>> Function(
    ConfirmSend<LimitOrderRequest> effect,
  )
  create,
  Future<ExchangeRead<List<LimitOrder>>> Function() recentOrders,
});

/// Why a destination could not be used.
final class LimitDestinationFailure extends Failure {
  const LimitDestinationFailure([super.logMessage]);
}

typedef PaymentRequestParser = Future<PaymentRequest> Function(String data);

/// [text] trimmed when it is a Lightning address (LNURL / user@domain), not
/// a bolt11 invoice or any other payment string.
Future<String?> lightningAddressOf(
  String text, {
  PaymentRequestParser parse = PaymentRequest.parse,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    final request = await parse(trimmed);
    return request is LnAddressPaymentRequest ? trimmed : null;
  } on Error {
    rethrow;
  } catch (_) {
    return null;
  }
}

LimitFlowCalls limitFlowCallsOf(
  Exchange exchange,
  ExchangeSession session,
  ExchangePayoutWallets payouts, {
  PaymentRequestParser parse = PaymentRequest.parse,
}) {
  final registrations = <String, WalletRegistration>{};
  Future<List<LimitAppWallet>> appWallets() async {
    final wallets = <WalletRegistration>[];
    final networks = switch (session.environment) {
      ExchangeEnvironment.mainnet => const <Network>[
        BitcoinNetwork.mainnet,
        LiquidNetwork.mainnet,
      ],
      ExchangeEnvironment.testnet => const <Network>[
        BitcoinNetwork.testnet,
        LiquidNetwork.testnet,
      ],
    };
    for (final network in networks) {
      switch (await payouts.walletsForNetwork(network)) {
        case Ok(:final value):
          wallets.addAll(value.wallets.where((w) => w.network == network));
        // A wallet list that can't be read offers no app wallet; the
        // default wallets and a Lightning address remain.
        case Err(:final failure):
          log.warning(
            'Failed to list wallets for a limit order: ${failure.runtimeType}',
          );
      }
    }
    wallets.sort((left, right) => left.id.compareTo(right.id));
    registrations
      ..clear()
      ..addEntries(wallets.map((w) => MapEntry(w.id, w)));
    return [
      for (final wallet in wallets)
        LimitAppWallet(
          wallet.id,
          wallet.network is LiquidNetwork
              ? BtcNetwork.liquid
              : BtcNetwork.bitcoin,
          label: wallet.label,
        ),
    ];
  }

  return (
    loadContext: () async {
      final (summary, defaults, wallets, entries) = await (
        exchange.getUserSummary(session.environment),
        exchange.readDefaultWallets(session),
        appWallets(),
        exchange.openUnknownWrites(),
      ).wait;
      final summaryRead = readOfResult(summary);
      // A journal that can't be read leaves no entry to start from; the
      // write gate then refuses the create itself (JournalUnreadable).
      final open = switch (entries) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      return switch ((summaryRead, defaults)) {
        (ReadGot(value: final s), ReadGot(value: final d)) => ReadGot(
          LimitOrderContext(s, d, wallets, open),
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
        readOfResult(await exchange.limitOrders.getRate(market.currency.code)),
    receiveAddress: (option) async {
      final wallet = registrations[option.walletId];
      if (wallet == null) {
        return const Err(LimitDestinationFailure('wallet no longer listed'));
      }
      return switch (await payouts.receive(wallet, advance: false)) {
        final address? => Ok(
          DestinationAppWallet(option.walletId, option.rail, address),
        ),
        null => const Err(
          LimitDestinationFailure('receive address unavailable'),
        ),
      };
    },
    lightningAddress: (text) async => switch (await lightningAddressOf(
      text,
      parse: parse,
    )) {
      final address? => Ok(DestinationAddress(BtcNetwork.lightning, address)),
      null => const Err(LimitDestinationFailure('not a lightning address')),
    },
    create: (effect) => runServerConfirm(
      gate: exchange.writeGate,
      session: session,
      policy: limitOrderCreatePolicy,
      effect: effect,
      // The create goes to the account of the current session: never to
      // another one the user signed into since.
      confirm: (request) async => exchange.currentSession != session
          ? const WriteNotSent(ExchangeNotSentReason.sessionChanged)
          : await exchange.limitOrders.create(request.draft),
    ),
    recentOrders: () async {
      // Settles the journal entries the re-read decides, so a create seen
      // here no longer holds the write gate.
      final _ = await exchange.reconcileUnknownWrites();
      return readOfResult(await exchange.limitOrders.listRecent());
    },
  );
}

/// Shell of [transitionLimitFlow]: applies events one at a time, emits the
/// new state and runs its effects. Every answer carries the attempt, market
/// or option that asked for it; the machine drops stale ones.
class LimitFlowBloc extends Bloc<LimitFlowEvent, LimitFlowState> {
  LimitFlowBloc({
    required LimitFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         limitFlowStart(session),
       );

  LimitFlowBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    LimitFlowNext start,
  ) : super(start.state) {
    on<LimitFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(LimitSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final LimitFlowCalls? _calls;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(LimitFlowEvent event, Emitter<LimitFlowState> emit) {
    final next = transitionLimitFlow(state, event);
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<LimitFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case LimitLoadContext(:final attempt):
          _answer(
            calls.loadContext().then((r) => LimitContextLoaded(attempt, r)),
          );
        case LimitReloadForDetour():
          _answer(calls.loadContext().then(LimitDetourLoaded.new));
        case LimitFetchTargetRate(:final market, :final attempt):
          _answer(
            calls
                .rate(market)
                .then((r) => LimitTargetRateArrived(market, attempt, r)),
          );
        case LimitFetchReviewRate(:final market, :final attempt):
          _answer(
            calls.rate(market).then((r) => LimitReviewRateArrived(attempt, r)),
          );
        case LimitDestinationEffect(:final effect):
          _destination(calls, effect);
        case LimitConfirmEffect(:final effect):
          _confirm(calls, effect);
      }
    }
  }

  void _destination(
    LimitFlowCalls calls,
    PickEffect<DestinationOption> effect,
  ) {
    switch (effect) {
      case PickResolve(:final option):
        final Future<Result<Destination, Failure>> resolved = switch (option) {
          final DestinationOptionAppWallet wallet => calls.receiveAddress(
            wallet,
          ),
          // A default wallet is a value at once (destinationResolution).
          DestinationOptionDefaultWallet(:final rail, :final address) =>
            Future.value(Ok(DestinationDefaultWallet(rail, address))),
        };
        _answer(
          resolved.then(
            (r) => LimitDestinationChanged(PickResolved(option, r)),
          ),
        );
      case PickValidate(:final text):
        _answer(
          calls
              .lightningAddress(text)
              .then((r) => LimitDestinationChanged(PickValidated(text, r))),
        );
    }
  }

  void _confirm(
    LimitFlowCalls calls,
    ServerConfirmEffect<LimitOrderRequest> effect,
  ) {
    switch (effect) {
      case final ConfirmSend<LimitOrderRequest> send:
        _answer(calls.create(send).then(LimitConfirmChanged.new));
      case ConfirmVerify(:final target, :final attempt):
        _answer(
          calls.recentOrders().then(
            (read) => LimitConfirmChanged(
              ConfirmVerified(attempt, limitOrderCreateCheck(target, read)),
            ),
          ),
        );
    }
  }

  void _answer(Future<LimitFlowEvent> answer) {
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
