import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_state.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_event.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_switch_effect.dart';
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
    next = next.next(event).state;
  }
  return next;
}

const _on = SwitchOn(restricted: false);
const _off = SwitchOff(restricted: false);
final _deactivating = _apply(_on, const [SwitchDeactivatePressed()]);
final _unverified = _apply(_deactivating, const [
  SwitchConfirmChanged(
    ConfirmAnswered(1, Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
  ),
  SwitchConfirmChanged(
    ConfirmVerified(1, ConfirmCheckFailed(ReadProblemMalformed())),
  ),
]);
const _ended = SwitchSessionEnded();

final _states = <String, AutoBuySwitchState>{
  'on': _on,
  'off': _off,
  'deactivating': _deactivating,
  'unverified': _unverified,
  'ended': _ended,
};

final _events = <String, AutoBuySwitchEvent>{
  'summary': const SwitchSummaryChanged(active: false, restricted: false),
  'deactivate': const SwitchDeactivatePressed(),
  'retry': const SwitchRetryPressed(),
  'confirm': const SwitchConfirmChanged(
    ConfirmAnswered(1, Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
  ),
};

const _moves = <(String, String), Type>{
  ('on', 'summary'): SwitchOff,
  ('on', 'deactivate'): SwitchDeactivating,
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
          final next = state.next(event);
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
            Err(
              ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
            ),
          ),
        ),
      ]) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      SwitchOn,
      SwitchOff,
      SwitchDeactivating,
      SwitchSessionEnded,
    });
  });

  test('deactivating writes off once, then verifies by re-reading', () {
    final next = _on.next(const SwitchDeactivatePressed());
    expect(next.effects, [
      const SwitchConfirmEffect(ConfirmSend(AutoBuyTarget(enabled: false), 1)),
    ]);
    expect(
      identical(
        next.state.next(const SwitchDeactivatePressed()).state,
        next.state,
      ),
      isTrue,
    );
  });

  test(
    'a verified write shows the re-read and refreshes the account (AB-3)',
    () {
      final verified = _deactivating.next(
        const SwitchConfirmChanged(ConfirmAnswered(1, Ok(false))),
      );
      expect(verified.state, const SwitchOff(restricted: false));
      expect(verified.effects, [const SwitchAccountChanged()]);
    },
  );

  test('a summary that arrives while writing is a stay', () {
    expect(
      identical(
        _deactivating
            .next(const SwitchSummaryChanged(active: true, restricted: false))
            .state,
        _deactivating,
      ),
      isTrue,
    );
  });

  test('a write the re-read shows not applied says so, offered again', () {
    final failed = _apply(_deactivating, const [
      SwitchConfirmChanged(
        ConfirmAnswered(1, Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
      ),
      SwitchConfirmChanged(ConfirmVerified(1, ConfirmSeenNotApplied())),
    ]);
    expect(
      failed,
      isA<SwitchOn>().having(
        (s) => s.problem,
        'problem',
        isA<SwitchWriteFailed>(),
      ),
    );
  });

  test('a summary that turns AutoBuy on shows it on', () {
    expect(
      _off
          .next(const SwitchSummaryChanged(active: true, restricted: false))
          .state,
      _on,
    );
  });

  test('an inactive switch offers no deactivation', () {
    expect(
      identical(_off.next(const SwitchDeactivatePressed()).state, _off),
      isTrue,
    );
  });
}
