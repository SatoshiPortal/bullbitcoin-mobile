import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// The limit-order calls of one test: each answers what it was given and
/// throws when the test gave none; every call is logged.
final class LimitTestOrders extends Fake implements ExchangeLimitOrders {
  Result<List<LimitOrder>, ExchangeFailure>? active;
  Result<List<LimitOrder>, ExchangeFailure>? recent;
  Result<LimitOrder, ExchangeFailure>? read;
  ExchangeWrite<LimitOrder>? created;
  Result<LimitOrder, ExchangeFailure>? cancelled;
  Result<List<LimitOrder>, ExchangeFailure>? cancelledAll;
  Result<LimitOrderRate, ExchangeFailure>? rate;
  final log = <String>[];

  T _given<T>(T? answer, String call) =>
      answer ?? (throw StateError('unexpected $call'));

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive() async {
    log.add('active');
    return _given(active, 'active');
  }

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listRecent() async {
    log.add('recent');
    return _given(recent, 'recent');
  }

  @override
  Future<Result<LimitOrder, ExchangeFailure>> get(String id) async {
    log.add('get $id');
    return _given(read, 'get');
  }

  @override
  Future<ExchangeWrite<LimitOrder>> create(LimitOrderDraft draft) async {
    log.add(
      'create ${draft.fiatAmount} ${draft.currency.code} '
      '${draft.limitPrice} ${draft.address}',
    );
    return _given(created, 'create');
  }

  @override
  Future<Result<LimitOrder, ExchangeFailure>> cancel(String id) async {
    log.add('cancel $id');
    return _given(cancelled, 'cancel');
  }

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll() async {
    log.add('cancelAll');
    return _given(cancelledAll, 'cancelAll');
  }

  @override
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    String currencyCode,
  ) async {
    log.add('rate $currencyCode');
    return _given(rate, 'rate');
  }
}
