import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list_event.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

import '../limit_order_fixtures.dart';

import 'package:primitives/primitives.dart';

List<LimitOrder> _orders(int count) =>
    List.generate(count, (i) => limitOrder(id: 'lo-$i'));

final _two = _orders(2);

LimitOrdersListState _apply(
  LimitOrdersListState state,
  List<LimitOrdersListEvent> events,
) {
  var next = state;
  for (final event in events) {
    next = next.next(event).state;
  }
  return next;
}

const _loading = ListLoading(1);
final _failed = _apply(_loading, const [
  ListLoaded(1, Err(ExchangeUnreachableFailure('down', isNetwork: true))),
]);
final _signedOut = _apply(_loading, const [
  ListLoaded(
    1,
    Err(ExchangeSessionRejectedFailure(ExchangeSessionRejection.server)),
  ),
]);
final _shown = _apply(_loading, [ListLoaded(1, Ok(_two))]);
final _refreshing = _apply(_shown, const [ListRefreshRequested()]);
final _cancelling = _apply(_shown, const [ListCancelAllPressed()]);

final _states = <String, LimitOrdersListState>{
  'loading': _loading,
  'failed': _failed,
  'signedOut': _signedOut,
  'shown': _shown,
  'refreshing': _refreshing,
  'cancelling': _cancelling,
};

/// Answers of attempt 1: only the first load's are current.
final _events = <String, LimitOrdersListEvent>{
  'loaded': ListLoaded(1, Ok(_two)),
  'refresh': const ListRefreshRequested(),
  'retry': const ListRetryPressed(),
  'cancelAll': const ListCancelAllPressed(),
  'cancelAnswered': const ListCancelAllAnswered(1, Ok(null)),
};

const _moves = <(String, String), Type>{
  ('loading', 'loaded'): ListShown,
  ('failed', 'refresh'): ListLoading,
  ('failed', 'retry'): ListLoading,
  ('signedOut', 'refresh'): ListLoading,
  ('signedOut', 'retry'): ListLoading,
  ('shown', 'refresh'): ListRefreshing,
  ('shown', 'retry'): ListRefreshing,
  ('shown', 'cancelAll'): ListCancellingAll,
  ('refreshing', 'refresh'): ListRefreshing,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_failed, isA<ListFailed>());
    expect(_signedOut, isA<ListSignedOut>());
    expect(_shown, isA<ListShown>());
    expect(_refreshing, isA<ListRefreshing>());
    expect(_cancelling, isA<ListCancellingAll>());
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
          }
        });
      }
    }
  });

  test('every state is reachable', () {
    final reached = <Type>{limitOrdersListStart.state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      ListLoading,
      ListFailed,
      ListSignedOut,
      ListShown,
      ListRefreshing,
      ListCancellingAll,
    });
  });

  test('a list read that started before a cancel-all is a stay (LIM-7)', () {
    final refreshing = _refreshing as ListRefreshing;
    final cancelling = ListShown(
      refreshing.orders,
      refreshing.attempt,
    ).next(const ListCancelAllPressed()).state;
    expect(
      identical(
        cancelling.next(ListLoaded(refreshing.attempt, Ok(_two))).state,
        cancelling,
      ),
      isTrue,
    );
  });

  test('a cancel-all reads the list again after any answer', () {
    final cancelling = _cancelling as ListCancellingAll;
    for (final answer in const <Result<void, ExchangeGatedWriteFailure>>[
      Ok(null),
      Err(ExchangeWriteOutcomeUnknownFailure('unsure')),
    ]) {
      final next = cancelling.next(
        ListCancelAllAnswered(cancelling.attempt, answer),
      );
      expect(next.state, isA<ListRefreshing>());
      expect(next.effects, [ListFetch(cancelling.attempt + 1)]);
    }
  });

  test('orders left after an unsure cancel-all are said so', () {
    final cancelling = _cancelling as ListCancellingAll;
    final refreshing = cancelling
        .next(
          ListCancelAllAnswered(
            cancelling.attempt,
            const Err(ExchangeWriteOutcomeUnknownFailure('unsure')),
          ),
        )
        .state;
    final shown = refreshing
        .next(ListLoaded(refreshing.attempt, Ok(_two)))
        .state;
    expect(
      shown,
      isA<ListShown>().having(
        (s) => s.problem,
        'problem',
        isA<ListCancelAllNotApplied>(),
      ),
    );
  });

  test('a refused cancel-all keeps the orders and says why', () {
    final cancelling = _cancelling as ListCancellingAll;
    expect(
      cancelling
          .next(
            ListCancelAllAnswered(
              cancelling.attempt,
              const Err(ExchangeWriteBusyFailure(WriteGateJournalUnreadable())),
            ),
          )
          .state,
      isA<ListShown>().having(
        (s) => s.problem,
        'problem',
        isA<ListCancelAllRefused>(),
      ),
    );
  });

  test('a failed refresh keeps the orders shown', () {
    final refreshing = _refreshing as ListRefreshing;
    expect(
      refreshing
          .next(
            ListLoaded(
              refreshing.attempt,
              const Err(ExchangeUnreachableFailure('down', isNetwork: true)),
            ),
          )
          .state,
      isA<ListShown>()
          .having((s) => s.orders, 'orders', same(_two))
          .having((s) => s.problem, 'problem', isA<ListRefreshFailed>()),
    );
  });

  test('the maximum of active orders stops creating', () {
    expect(ListShown(_orders(4), 1).canCreate, isTrue);
    expect(ListShown(_orders(maximumActiveLimitOrders), 1).canCreate, isFalse);
  });
}
