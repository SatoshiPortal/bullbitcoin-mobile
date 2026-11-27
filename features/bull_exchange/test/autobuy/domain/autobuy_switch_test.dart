import 'package:bull_exchange/src/autobuy/domain/autobuy_flow.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

AutoBuySwitchState _apply(
  AutoBuySwitchState state,
  List<AutoBuySwitchEvent> events,
) {
  var next = state;
  for (final event in events) {
    next = transitionAutoBuySwitch(next, event).state;
  }
  return next;
}

const _on = SwitchShown(active: true, restricted: false);
final _deactivating = _apply(_on, const [SwitchDeactivatePressed()]);
final _unverified = _apply(_deactivating, const [
  SwitchConfirmChanged(
    ConfirmAnswered(
      1,
      GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
    ),
  ),
  SwitchConfirmChanged(
    ConfirmVerified(1, ConfirmCheckFailed(ReadProblemMalformed())),
  ),
]);
const _ended = SwitchSessionEnded(true, false);

final _states = <String, AutoBuySwitchState>{
  'shown': _on,
  'deactivating': _deactivating,
  'unverified': _unverified,
  'ended': _ended,
};

final _events = <String, AutoBuySwitchEvent>{
  'summary': const SwitchSummaryChanged(active: false, restricted: false),
  'deactivate': const SwitchDeactivatePressed(),
  'retry': const SwitchRetryPressed(),
  'confirm': const SwitchConfirmChanged(
    ConfirmAnswered(
      1,
      GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
    ),
  ),
};

const _moves = <(String, String), Type>{
  ('shown', 'summary'): SwitchShown,
  ('shown', 'deactivate'): SwitchDeactivating,
  ('deactivating', 'confirm'): SwitchDeactivating,
  ('unverified', 'retry'): SwitchDeactivating,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_deactivating, isA<SwitchDeactivating>());
    expect(
      (_unverified as SwitchDeactivating).confirm,
      isA<ConfirmUnverified<AutoBuyTarget, bool>>(),
    );
  });

  group('every (state, event) pair', () {
    for (final MapEntry(key: stateName, value: state) in _states.entries) {
      for (final MapEntry(key: eventName, value: event) in _events.entries) {
        final expected = _moves[(stateName, eventName)];
        test('$stateName + $eventName', () {
          final next = transitionAutoBuySwitch(state, event);
          if (expected == null) {
            expect(identical(next.state, state), isTrue, reason: '$next');
            expect(next.effects, isEmpty);
          } else {
            expect(next.state.runtimeType, expected);
            expect(identical(next.state, state), isFalse);
          }
        });
      }
    }
  });

  test('every state is reachable', () {
    final reached = <Type>{};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in [
        ..._events.values,
        const SwitchConfirmChanged(
          ConfirmAnswered(
            1,
            GateAdmitted(
              Err(
                ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
              ),
            ),
          ),
        ),
      ]) {
        reached.add(transitionAutoBuySwitch(state, event).state.runtimeType);
      }
    }
    expect(reached, {SwitchShown, SwitchDeactivating, SwitchSessionEnded});
  });

  test('deactivating writes off once, then verifies by re-reading', () {
    final next = transitionAutoBuySwitch(_on, const SwitchDeactivatePressed());
    expect(next.effects, [
      const SwitchConfirmEffect(ConfirmSend(AutoBuyTarget(enabled: false), 1)),
    ]);
    expect(
      identical(
        transitionAutoBuySwitch(
          next.state,
          const SwitchDeactivatePressed(),
        ).state,
        next.state,
      ),
      isTrue,
    );
  });

  test(
    'a verified write shows the re-read and refreshes the account (AB-3)',
    () {
      final verified = transitionAutoBuySwitch(
        _deactivating,
        const SwitchConfirmChanged(ConfirmAnswered(1, GateAdmitted(Ok(false)))),
      );
      expect(
        verified.state,
        const SwitchShown(active: false, restricted: false),
      );
      expect(verified.effects, [const SwitchAccountChanged()]);
    },
  );

  test('a summary that arrives while writing is a stay', () {
    expect(
      identical(
        transitionAutoBuySwitch(
          _deactivating,
          const SwitchSummaryChanged(active: true, restricted: false),
        ).state,
        _deactivating,
      ),
      isTrue,
    );
  });

  test('a write the re-read shows not applied says so, offered again', () {
    final failed = _apply(_deactivating, const [
      SwitchConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        ),
      ),
      SwitchConfirmChanged(ConfirmVerified(1, ConfirmSeenNotApplied())),
    ]);
    expect(
      failed,
      isA<SwitchShown>()
          .having((s) => s.active, 'active', isTrue)
          .having((s) => s.problem, 'problem', isA<SwitchWriteFailed>()),
    );
  });

  test('an inactive switch offers no deactivation', () {
    const off = SwitchShown(active: false, restricted: false);
    expect(
      identical(
        transitionAutoBuySwitch(off, const SwitchDeactivatePressed()).state,
        off,
      ),
      isTrue,
    );
  });
}
