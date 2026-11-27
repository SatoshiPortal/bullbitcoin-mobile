import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/limit_order.dart';
import '../entities/limit_order_draft.dart';
import '../entities/limit_order_rate.dart';
import '../exchange_access.dart';
import '../exchange_failure.dart';

/// Limit-order queries and commands, each for the [ExchangeSession] it names.
/// A session that is no longer the current one is never acted on: reads and
/// cancels answer [ExchangeOperationStaleFailure], a create is not sent.
abstract interface class LimitOrdersRepository {
  @useResult
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive(
    ExchangeSession session,
  );

  /// The most recent limit orders in every status, newest first.
  @useResult
  Future<Result<List<LimitOrder>, ExchangeFailure>> listRecent(
    ExchangeSession session,
  );
  @useResult
  Future<Result<LimitOrder, ExchangeFailure>> get(
    ExchangeSession session,
    String id,
  );

  /// [ExchangeWriteOutcomeUnknownFailure] means the order may exist: re-read the recent
  /// limit orders ([findCreatedLimitOrder]) before creating again.
  @useResult
  Future<Result<LimitOrder, ExchangeWriteFailure>> create(
    ExchangeSession session,
    LimitOrderDraft draft,
  );
  @useResult
  Future<Result<LimitOrder, ExchangeFailure>> cancel(
    ExchangeSession session,
    String id,
  );
  @useResult
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll(
    ExchangeSession session,
  );
  @useResult
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    ExchangeSession session,
    String currencyCode,
  );
}
