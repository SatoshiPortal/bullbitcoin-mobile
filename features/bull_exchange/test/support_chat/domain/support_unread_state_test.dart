import 'package:bull_exchange/src/support_chat/domain/support_unread_state.dart';
import 'package:bull_exchange/src/support_chat/domain/support_unread_event.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _a = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _b = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

const _signedInA = ExchangeAccessSignedIn(_a);
const _signedInB = ExchangeAccessSignedIn(_b);
const _signedOut = ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
const _offline = Err<int, ExchangeReadFailure>(
  ExchangeUnreachableFailure('offline', isNetwork: true),
);

/// One state of each kind, all on session a, attempt 2.
const _states = <SupportUnreadState>[
  UnreadSignedOut(), // 0
  UnreadReading(_a, 2), // 1
  UnreadUnavailable(_a, 2, UnreadProblem.unreachable), // 2
  UnreadKnown(_a, 2, 4), // 3
  UnreadRefreshing(_a, 2, 4), // 4
  UnreadStale(_a, 2, 4, UnreadProblem.malformed), // 5
  UnreadMarking(_a, 2), // 6
];

const _signedIn = [1, 2, 3, 4, 5, 6];

/// event -> {state index: expected state}; a missing index is a stay.
final _table = <String, (SupportUnreadEvent, Map<int, SupportUnreadState>)>{
  'sign-in': (
    const UnreadAccessChanged(_signedInA),
    {0: const UnreadReading(_a, 0)},
  ),
  'another session': (
    const UnreadAccessChanged(_signedInB),
    {
      for (final i in [0, ..._signedIn]) i: const UnreadReading(_b, 0),
    },
  ),
  'sign-out': (
    const UnreadAccessChanged(_signedOut),
    {for (final i in _signedIn) i: const UnreadSignedOut()},
  ),
  'recheck': (
    const UnreadRecheckRequested(),
    {
      1: const UnreadReading(_a, 3),
      2: const UnreadReading(_a, 3),
      3: const UnreadRefreshing(_a, 3, 4),
      4: const UnreadRefreshing(_a, 3, 4),
      5: const UnreadRefreshing(_a, 3, 4),
    },
  ),
  'chat shown': (
    const UnreadChatShown(),
    {for (final i in _signedIn) i: const UnreadMarking(_a, 3)},
  ),
  'count read': (
    const UnreadCountAnswered(_a, 2, Ok(7)),
    {1: const UnreadKnown(_a, 2, 7), 4: const UnreadKnown(_a, 2, 7)},
  ),
  'count failed': (
    const UnreadCountAnswered(_a, 2, _offline),
    {
      1: const UnreadUnavailable(_a, 2, UnreadProblem.unreachable),
      4: const UnreadStale(_a, 2, 4, UnreadProblem.unreachable),
    },
  ),
  'count malformed': (
    const UnreadCountAnswered(_a, 2, Err(ExchangeMalformedFailure('negative'))),
    {
      1: const UnreadUnavailable(_a, 2, UnreadProblem.malformed),
      4: const UnreadStale(_a, 2, 4, UnreadProblem.malformed),
    },
  ),
  'count of an older attempt': (const UnreadCountAnswered(_a, 1, Ok(7)), {}),
  'count of another session': (const UnreadCountAnswered(_b, 2, Ok(7)), {}),
  'marked': (
    const UnreadMarkAnswered(_a, 2, Ok(null)),
    {6: const UnreadRefreshing(_a, 3, 0)},
  ),
  'mark refused': (
    const UnreadMarkAnswered(
      _a,
      2,
      Err(ExchangeWriteRefusedFailure(ExchangeRefusal())),
    ),
    {6: const UnreadReading(_a, 3)},
  ),
  'mark outcome unknown': (
    const UnreadMarkAnswered(
      _a,
      2,
      Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
    ),
    {6: const UnreadReading(_a, 3)},
  ),
  'mark of an older attempt': (const UnreadMarkAnswered(_a, 1, Ok(null)), {}),
};

void main() {
  group('every (state, event) pair', () {
    for (final MapEntry(key: name, value: (event, changes)) in _table.entries) {
      for (final (index, state) in _states.indexed) {
        test('$name from state $index', () {
          expect(state.next(event), changes[index] ?? state);
        });
      }
    }
  });

  test(
    'a count read before the chat was shown cannot bring the badge back',
    () {
      var state = (const UnreadKnown(
        _a,
        2,
        4,
      )).next(const UnreadRecheckRequested());
      state = state.next(const UnreadChatShown());
      state = state.next(const UnreadCountAnswered(_a, 3, Ok(4)));
      expect(supportUnreadBadge(state), 0);
    },
  );

  test('the badge shows a known count only', () {
    expect(
      [for (final state in _states) supportUnreadBadge(state)],
      [0, 0, 0, 4, 4, 4, 0],
    );
  });

  test('every state is reachable from signed out', () {
    final seen = <Type>{};
    final queue = <SupportUnreadState>[const UnreadSignedOut()];
    final visited = <SupportUnreadState>{};
    while (queue.isNotEmpty && visited.length < 500) {
      final state = queue.removeAt(0);
      if (!visited.add(state)) continue;
      seen.add(state.runtimeType);
      final answers = switch (state) {
        UnreadReading(:final session, :final attempt) ||
        UnreadRefreshing(:final session, :final attempt) => [
          UnreadCountAnswered(session, attempt, const Ok(1)),
          UnreadCountAnswered(session, attempt, _offline),
        ],
        UnreadMarking(:final session, :final attempt) => [
          UnreadMarkAnswered(session, attempt, const Ok(null)),
          UnreadMarkAnswered(
            session,
            attempt,
            const Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
          ),
        ],
        UnreadSignedOut() ||
        UnreadUnavailable() ||
        UnreadKnown() ||
        UnreadStale() => const <SupportUnreadEvent>[],
      };
      for (final event in [
        const UnreadAccessChanged(_signedInA),
        const UnreadRecheckRequested(),
        const UnreadChatShown(),
        ...answers,
      ]) {
        queue.add(state.next(event));
      }
    }
    expect(seen, {for (final state in _states) state.runtimeType});
  });
}
