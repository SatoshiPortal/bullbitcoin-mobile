import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// The limit-order calls of one test: each answers what it was given and
/// throws when the test gave none; every call is logged.
final class LimitTestOrders extends Fake implements LimitOrdersRepository {
  Result<List<LimitOrder>, ExchangeFailure>? active;
  Result<List<LimitOrder>, ExchangeFailure>? recent;
  Result<LimitOrder, ExchangeFailure>? read;
  Result<LimitOrder, ExchangeWriteFailure>? created;
  Result<LimitOrder, ExchangeFailure>? cancelled;
  Result<List<LimitOrder>, ExchangeFailure>? cancelledAll;
  Result<LimitOrderRate, ExchangeFailure>? rate;
  final log = <String>[];

  /// The session each call named, in call order.
  final sessions = <ExchangeSession>[];

  /// The signed-in session, when the test sets one: like the real
  /// repository, a call for another session is refused before anything is
  /// sent (and not logged).
  ExchangeSession? current;

  bool _stale(ExchangeSession session) => current != null && current != session;

  T _given<T>(T? answer, String call) =>
      answer ?? (throw StateError('unexpected $call'));

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive(
    ExchangeSession session,
  ) async {
    sessions.add(session);
    if (_stale(session)) return const Err(ExchangeOperationStaleFailure());
    log.add('active');
    return _given(active, 'active');
  }

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listRecent(
    ExchangeSession session,
  ) async {
    sessions.add(session);
    if (_stale(session)) return const Err(ExchangeOperationStaleFailure());
    log.add('recent');
    return _given(recent, 'recent');
  }

  @override
  Future<Result<LimitOrder, ExchangeFailure>> get(
    ExchangeSession session,
    String id,
  ) async {
    sessions.add(session);
    if (_stale(session)) return const Err(ExchangeOperationStaleFailure());
    log.add('get $id');
    return _given(read, 'get');
  }

  @override
  Future<Result<LimitOrder, ExchangeWriteFailure>> create(
    ExchangeSession session,
    LimitOrderDraft draft,
  ) async {
    sessions.add(session);
    if (_stale(session)) {
      return const Err(
        ExchangeWriteNotSentFailure(ExchangeNotSentReason.sessionChanged),
      );
    }
    log.add(
      'create ${draft.fiatAmount} ${draft.currency.code} '
      '${draft.limitPrice} ${draft.address}',
    );
    return _given(created, 'create');
  }

  @override
  Future<Result<LimitOrder, ExchangeFailure>> cancel(
    ExchangeSession session,
    String id,
  ) async {
    sessions.add(session);
    if (_stale(session)) return const Err(ExchangeOperationStaleFailure());
    log.add('cancel $id');
    return _given(cancelled, 'cancel');
  }

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll(
    ExchangeSession session,
  ) async {
    sessions.add(session);
    if (_stale(session)) return const Err(ExchangeOperationStaleFailure());
    log.add('cancelAll');
    return _given(cancelledAll, 'cancelAll');
  }

  @override
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    ExchangeSession session,
    String currencyCode,
  ) async {
    sessions.add(session);
    if (_stale(session)) return const Err(ExchangeOperationStaleFailure());
    log.add('rate $currencyCode');
    return _given(rate, 'rate');
  }
}
