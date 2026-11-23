import 'package:primitives/primitives.dart';

import 'entities/limit_order.dart';
import 'entities/limit_order_draft.dart';
import 'entities/limit_order_rate.dart';
import 'exchange_failure.dart';

/// Limit-order queries and commands. The Exchange session selects the backend.
abstract interface class ExchangeLimitOrders {
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive();
  Future<Result<LimitOrder, ExchangeFailure>> get(String id);
  Future<Result<LimitOrder, ExchangeFailure>> create(LimitOrderDraft draft);
  Future<Result<LimitOrder, ExchangeFailure>> cancel(String id);
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll();
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(String currencyCode);
}

final class ExchangeLimitOrdersImpl implements ExchangeLimitOrders {
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function() _list;
  final Future<Result<LimitOrder, ExchangeFailure>> Function(String) _get;
  final Future<Result<LimitOrder, ExchangeFailure>> Function(LimitOrderDraft)
  _create;
  final Future<Result<LimitOrder, ExchangeFailure>> Function(String) _cancel;
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function() _cancelAll;
  final Future<Result<LimitOrderRate, ExchangeFailure>> Function(String) _rate;

  const ExchangeLimitOrdersImpl({
    required this._list,
    required this._get,
    required this._create,
    required this._cancel,
    required this._cancelAll,
    required this._rate,
  });

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive() => _list();
  @override
  Future<Result<LimitOrder, ExchangeFailure>> get(String id) => _get(id);
  @override
  Future<Result<LimitOrder, ExchangeFailure>> create(LimitOrderDraft draft) =>
      _create(draft);
  @override
  Future<Result<LimitOrder, ExchangeFailure>> cancel(String id) => _cancel(id);
  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll() => _cancelAll();
  @override
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    String currencyCode,
  ) => _rate(currencyCode);
}
