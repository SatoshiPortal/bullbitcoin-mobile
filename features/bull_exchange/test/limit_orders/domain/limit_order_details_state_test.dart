import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel_event.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_event.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

import '../limit_order_fixtures.dart';

import 'package:primitives/primitives.dart';

final _active = limitOrder();
final _cancelled = limitOrder(status: LimitOrderStatus.cancelled);

LimitDetailsState _apply(
  LimitDetailsState state,
  List<LimitDetailsEvent> events,
) {
  var next = state;
  for (final event in events) {
    next = next.next(event).state;
  }
  return next;
}

final _loading = limitDetailsStart(limitSession, _active.id).state;
final _failed = _apply(_loading, const [
  DetailsLoaded(1, Err(ExchangeUnreachableFailure('down', isNetwork: true))),
]);
final _shown = _apply(_loading, [DetailsLoaded(1, Ok(_active))]);
final _cancelling = _apply(_shown, const [
  DetailsCancelChanged(CancelPressed()),
]);
final _cancelledShown = _apply(_cancelling, [
  DetailsCancelChanged(CancelAnswered(1, CancelAnsweredOrder(_cancelled))),
]);
const _ended = DetailsSessionEnded(changed: false);
const _closed = DetailsClosed(changed: false);

final _states = <String, LimitDetailsState>{
  'loading': _loading,
  'failed': _failed,
  'shown': _shown,
  'cancelling': _cancelling,
  'ended': _ended,
  'closed': _closed,
};

final _events = <String, LimitDetailsEvent>{
  'loaded': DetailsLoaded(1, Ok(_active)),
  'retry': const DetailsRetryPressed(),
  'cancel': const DetailsCancelChanged(CancelPressed()),
  'back': const DetailsBackPressed(),
  'session': const DetailsSessionChanged(limitOtherSession),
};

const _moves = <(String, String), Type>{
  ('loading', 'loaded'): DetailsShown,
  ('loading', 'back'): DetailsClosed,
  ('loading', 'session'): DetailsSessionEnded,
  ('failed', 'retry'): DetailsLoading,
  ('failed', 'back'): DetailsClosed,
  ('failed', 'session'): DetailsSessionEnded,
  ('shown', 'cancel'): DetailsShown,
  ('shown', 'back'): DetailsClosed,
  ('shown', 'session'): DetailsSessionEnded,
  ('cancelling', 'session'): DetailsSessionEnded,
  ('ended', 'back'): DetailsClosed,
};

void main() {
  test('the sample states are the ones they name', () {
    expect(_failed, isA<DetailsFailed>());
    expect(_shown, isA<DetailsShown>());
    expect(
      _cancelling,
      isA<DetailsShown>().having(
        (s) => s.cancel,
        'cancel',
        isA<CancelSending>(),
      ),
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
          }
        });
      }
    }
  });

  test('every state is reachable', () {
    final reached = <Type>{limitDetailsStart(null, 'x').state.runtimeType};
    for (final state in _states.values) {
      reached.add(state.runtimeType);
      for (final event in _events.values) {
        reached.add(state.next(event).state.runtimeType);
      }
    }
    expect(reached, {
      DetailsLoading,
      DetailsFailed,
      DetailsShown,
      DetailsSessionEnded,
      DetailsClosed,
    });
  });

  test('the first read and a Retry read the order with their attempt', () {
    expect(limitDetailsStart(limitSession, 'lo-1').effects, [
      const DetailsRead('lo-1', 1),
    ]);
    expect(_failed.next(const DetailsRetryPressed()).effects, [
      const DetailsRead('lo-1', 2),
    ]);
  });

  test('Back while the cancel runs is a stay', () {
    expect(
      identical(
        _cancelling.next(const DetailsBackPressed()).state,
        _cancelling,
      ),
      isTrue,
    );
  });

  test('leaving after a cancel says the order changed', () {
    expect(
      _cancelledShown.next(const DetailsBackPressed()).state,
      const DetailsClosed(changed: true),
    );
    expect(
      _shown.next(const DetailsBackPressed()).state,
      const DetailsClosed(changed: false),
    );
  });

  test('a session ended during the cancel reloads the list on leaving', () {
    final ended = _cancelling
        .next(
          const DetailsCancelChanged(
            CancelAnswered(1, CancelAnsweredSessionRejected()),
          ),
        )
        .state;
    expect(ended, const DetailsSessionEnded(changed: true));
    expect(
      ended.next(const DetailsBackPressed()).state,
      const DetailsClosed(changed: true),
    );
  });
}
