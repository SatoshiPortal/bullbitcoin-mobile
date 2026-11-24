import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/limit_order.dart';
import 'entities/limit_order_draft.dart';
import 'entities/limit_order_rate.dart';
import 'exchange_call_result.dart';
import 'exchange_failure.dart';

/// Why the exchange refused a limit-order create, read from its code.
enum LimitOrderRefusal {
  /// The account already has the maximum of active limit orders.
  maximumActive,

  /// The payout address is not one the exchange accepts.
  invalidAddress,

  /// Any other refusal: nothing was created.
  other,
}

LimitOrderRefusal limitOrderRefusalOf(ExchangeRefusal refusal) =>
    switch (refusal.apiCode) {
      'ERR_ORDTRG_LOMAX429' => LimitOrderRefusal.maximumActive,
      'ERR_ORDTRG_ADDR400' => LimitOrderRefusal.invalidAddress,
      _ => LimitOrderRefusal.other,
    };

/// Limit-order queries and commands. The Exchange session selects the backend.
abstract interface class ExchangeLimitOrders {
  @useResult
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive();

  /// The most recent limit orders in every status, newest first.
  @useResult
  Future<Result<List<LimitOrder>, ExchangeFailure>> listRecent();
  @useResult
  Future<Result<LimitOrder, ExchangeFailure>> get(String id);

  /// [WriteOutcomeUnknown] means the order may exist: re-read the recent
  /// limit orders ([findCreatedLimitOrder]) before creating again.
  @useResult
  Future<ExchangeWrite<LimitOrder>> create(LimitOrderDraft draft);
  @useResult
  Future<Result<LimitOrder, ExchangeFailure>> cancel(String id);
  @useResult
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll();
  @useResult
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(String currencyCode);
}

final class ExchangeLimitOrdersImpl implements ExchangeLimitOrders {
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function() _list;
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function()
  _listRecent;
  final Future<Result<LimitOrder, ExchangeFailure>> Function(String) _get;
  final Future<ExchangeWrite<LimitOrder>> Function(LimitOrderDraft) _create;
  final Future<Result<LimitOrder, ExchangeFailure>> Function(String) _cancel;
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function() _cancelAll;
  final Future<Result<LimitOrderRate, ExchangeFailure>> Function(String) _rate;

  const ExchangeLimitOrdersImpl({
    required this._list,
    required this._listRecent,
    required this._get,
    required this._create,
    required this._cancel,
    required this._cancelAll,
    required this._rate,
  });

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive() => _list();
  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listRecent() =>
      _listRecent();
  @override
  Future<Result<LimitOrder, ExchangeFailure>> get(String id) => _get(id);
  @override
  Future<ExchangeWrite<LimitOrder>> create(LimitOrderDraft draft) =>
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
