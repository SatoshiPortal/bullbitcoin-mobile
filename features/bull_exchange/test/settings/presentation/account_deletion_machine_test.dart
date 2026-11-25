import 'package:bull_exchange/src/settings/presentation/account_deletion_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

const _failure = ExchangeAccountDeletionRequestFailure('test');

void main() {
  final states = <String, AccountDeletionState>{
    'Idle': const AccountDeletionIdle(),
    'Requesting': const AccountDeletionRequesting(),
    'Requested': const AccountDeletionRequested(),
    'Failed': const AccountDeletionFailed(_failure),
  };
  final events = <String, AccountDeletionEvent>{
    'Confirmed': const AccountDeletionConfirmed(),
    'Sent': const AccountDeletionSent(),
    'Stale': const AccountDeletionStale(),
    'NotSent': const AccountDeletionNotSent(_failure),
  };
  // Rows follow [events].
  final table = <String, List<AccountDeletionState>>{
    'Idle': [
      const AccountDeletionRequesting(),
      const AccountDeletionIdle(),
      const AccountDeletionIdle(),
      const AccountDeletionIdle(),
    ],
    'Requesting': [
      // B16: a second request while one runs is a stay.
      const AccountDeletionRequesting(),
      const AccountDeletionRequested(),
      const AccountDeletionIdle(),
      const AccountDeletionFailed(_failure),
    ],
    'Requested': [
      const AccountDeletionRequested(),
      const AccountDeletionRequested(),
      const AccountDeletionRequested(),
      const AccountDeletionRequested(),
    ],
    'Failed': [
      const AccountDeletionRequesting(),
      const AccountDeletionFailed(_failure),
      const AccountDeletionFailed(_failure),
      const AccountDeletionFailed(_failure),
    ],
  };

  test('the table names every (state, event) pair', () {
    expect(table.keys, states.keys);
    for (final row in table.values) {
      expect(row, hasLength(events.length));
    }
  });

  for (final MapEntry(key: stateName, value: state) in states.entries) {
    final eventNames = events.keys.toList();
    for (var i = 0; i < eventNames.length; i++) {
      test('$stateName x ${eventNames[i]}', () {
        final next = transitionAccountDeletion(state, events[eventNames[i]]!);
        final expected = table[stateName]![i];
        expect(next.runtimeType, expected.runtimeType);
        expect(next, expected);
      });
    }
  }

  test('every state is reachable from Idle', () {
    final seen = <Type>{AccountDeletionIdle};
    var frontier = <AccountDeletionState>[const AccountDeletionIdle()];
    while (frontier.isNotEmpty) {
      final next = <AccountDeletionState>[];
      for (final state in frontier) {
        for (final event in events.values) {
          final to = transitionAccountDeletion(state, event);
          if (seen.add(to.runtimeType)) next.add(to);
        }
      }
      frontier = next;
    }
    expect(seen, states.values.map((s) => s.runtimeType).toSet());
  });

  test('a double confirm sends one request', () {
    var state = transitionAccountDeletion(
      const AccountDeletionIdle(),
      const AccountDeletionConfirmed(),
    );
    final afterSecond = transitionAccountDeletion(
      state,
      const AccountDeletionConfirmed(),
    );
    expect(identical(afterSecond, state), isTrue);
    state = transitionAccountDeletion(state, const AccountDeletionSent());
    expect(state, isA<AccountDeletionRequested>());
  });
}
