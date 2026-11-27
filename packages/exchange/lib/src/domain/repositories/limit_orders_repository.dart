import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/limit_order.dart';
import '../entities/limit_order_draft.dart';
import '../entities/limit_order_rate.dart';
import '../exchange_call_result.dart';
import '../exchange_failure.dart';

/// Limit-order queries and commands. The Exchange session selects the backend.
abstract interface class LimitOrdersRepository {
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
