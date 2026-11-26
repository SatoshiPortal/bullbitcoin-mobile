import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_flow.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The exchange calls of AutoBuy, bound to one session.
typedef AutoBuyCalls = ({
  Future<ExchangeRead<AutoBuyContext>> Function() loadContext,
  Future<ConfirmAnswered<AutoBuyTarget, bool>> Function(
    ConfirmSend<AutoBuyTarget> effect,
  )
  write,
  Future<ConfirmCheck<bool>> Function(AutoBuyTarget target) verify,
});

AutoBuyCalls autoBuyCallsOf(Exchange exchange, ExchangeSession session) {
  Future<ExchangeRead<UserSummary>> summary() async =>
      readOfResult(await exchange.getUserSummary(session.environment));
  return (
    loadContext: () async {
      // One after the other: a record `.wait` would wrap a programmer error
      // of either read in a ParallelWaitError instead of rethrowing it.
      final read = await summary();
      final entries = await exchange.openUnknownWrites();
      // A journal that can't be read leaves no entry to start from; the
      // write gate then refuses the write itself (JournalUnreadable).
      final open = switch (entries) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      return switch (read) {
        ReadGot(:final value) => ReadGot(AutoBuyContext(value, open)),
        ReadMissing() => const ReadMissing(),
        ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
          reason,
          isNetwork: isNetwork,
        ),
        ReadSessionRejected(:final why) => ReadSessionRejected(why),
        ReadMalformed(:final reason) => ReadMalformed(reason),
      };
    },
    write: (effect) => runServerConfirm(
      gate: exchange.writeGate,
      session: session,
      policy: autoBuyWritePolicy,
      effect: effect,
      confirm: (target) async => switch (writeOfResult(
        await exchange.updatePreferences(
          session,
          ExchangePreferencesPatch(autoBuyEnabled: target.enabled),
        ),
      )) {
        // A save that returns normally is not proof the account
        // changed: the step re-reads it (verify after write).
        WriteDone() => const WriteOutcomeUnknown(
          'saved; verified by re-reading the account',
        ),
        final WriteRefused<void> w => WriteRefused(w.reason),
        final WriteNotSent<void> w => WriteNotSent(w.reason),
        final WriteOutcomeUnknown<void> w => WriteOutcomeUnknown(w.reason),
        WriteSessionRejected() => const WriteSessionRejected(),
      },
    ),
    verify: (target) async => autoBuyCheck(target, await summary()),
  );
}

/// Shell of [transitionAutoBuyFlow].
class AutoBuyFlowBloc extends Bloc<AutoBuyFlowEvent, AutoBuyFlowState> {
  AutoBuyFlowBloc({
    required AutoBuyCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         autoBuyFlowStart(session),
       );

  AutoBuyFlowBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    AutoBuyFlowNext start,
  ) : super(start.state) {
    on<AutoBuyFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(AutoBuySessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final AutoBuyCalls? _calls;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(AutoBuyFlowEvent event, Emitter<AutoBuyFlowState> emit) {
    final next = transitionAutoBuyFlow(state, event);
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<AutoBuyFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      final Future<AutoBuyFlowEvent> answer = switch (effect) {
        AutoBuyLoadContext(:final attempt) => calls.loadContext().then(
          (r) => AutoBuyContextLoaded(attempt, r),
        ),
        AutoBuyReloadForKyc() => calls.loadContext().then(
          AutoBuyKycReloaded.new,
        ),
        AutoBuyConfirmEffect(effect: final ConfirmSend<AutoBuyTarget> send) =>
          calls.write(send).then(AutoBuyConfirmChanged.new),
        AutoBuyConfirmEffect(
          effect: ConfirmVerify(:final target, :final attempt),
        ) =>
          calls
              .verify(target)
              .then(
                (check) =>
                    AutoBuyConfirmChanged(ConfirmVerified(attempt, check)),
              ),
      };
      unawaited(
        answer.then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }

  @override
  Future<void> close() async {
    await _access.cancel();
    return super.close();
  }
}

/// Shell of [transitionAutoBuySwitch]. Without a session the switch only
/// shows the summary.
class AutoBuySwitchBloc extends Bloc<AutoBuySwitchEvent, AutoBuySwitchState> {
  AutoBuySwitchBloc({
    required this._calls,
    required bool active,
    required bool restricted,
    required this._onAccountChanged,
  }) : super(autoBuySwitchStart(active: active, restricted: restricted).state) {
    on<AutoBuySwitchEvent>(_onEvent, transformer: sequential());
  }

  final AutoBuyCalls? _calls;
  final Future<void> Function() _onAccountChanged;

  void _onEvent(AutoBuySwitchEvent event, Emitter<AutoBuySwitchState> emit) {
    if (_calls == null && event is SwitchDeactivatePressed) return;
    final next = transitionAutoBuySwitch(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<AutoBuySwitchEffect> effects) {
    final calls = _calls;
    for (final effect in effects) {
      switch (effect) {
        case SwitchAccountChanged():
          unawaited(_onAccountChanged());
        case SwitchConfirmEffect(:final effect):
          if (calls == null) continue;
          final Future<AutoBuySwitchEvent> answer = switch (effect) {
            final ConfirmSend<AutoBuyTarget> send =>
              calls.write(send).then(SwitchConfirmChanged.new),
            ConfirmVerify(:final target, :final attempt) =>
              calls
                  .verify(target)
                  .then(
                    (check) =>
                        SwitchConfirmChanged(ConfirmVerified(attempt, check)),
                  ),
          };
          unawaited(
            answer.then((event) {
              if (!isClosed) add(event);
            }),
          );
      }
    }
  }
}
