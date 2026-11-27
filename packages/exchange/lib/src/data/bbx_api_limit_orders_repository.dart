import 'dart:math';

import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/limit_order.dart';
import '../domain/entities/limit_order_draft.dart';
import '../domain/entities/limit_order_rate.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_failure.dart';
import '../domain/repositories/limit_orders_repository.dart';
import 'exchange_call_classifier.dart';
import 'limit_order_status_wire.dart';

/// Runs a limit-order read on a client of [session], only while it is the
/// current session; a credential that can't be read answers a
/// [ExchangeLimitOrderFailure] of [problem].
typedef RunLimitOrderRead = Future<Result<T, ExchangeFailure>> Function<T>(
  ExchangeSession session,
  ExchangeLimitOrderProblem problem,
  Future<Result<T, ExchangeFailure>> Function(bbx.Bbx) operation,
);

/// Runs a limit-order write on a client of [session], only while it is the
/// current session.
typedef RunLimitOrderWrite = Future<Result<T, ExchangeFailure>> Function<T>(
  ExchangeSession session,
  Future<Result<T, ExchangeFailure>> Function(bbx.Bbx) operation,
);

/// [LimitOrdersRepository] on the `bbx_api` package.
final class BbxApiLimitOrdersRepository implements LimitOrdersRepository {
  final RunLimitOrderRead _read;
  final RunLimitOrderWrite _write;

  /// Records a create whose outcome is unknown before it is returned.
  final Future<void> Function(ExchangeSession session, LimitOrderDraft draft)
  _journalUnknownCreate;

  const BbxApiLimitOrdersRepository({
    required this._read,
    required this._write,
    required this._journalUnknownCreate,
  });

  /// The orders that may still execute: active ones and ones whose status
  /// this build doesn't know, so an unknown status neither hides an order nor
  /// frees a slot of the open-order cap.
  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive(
    ExchangeSession session,
  ) => _guard(
    session,
    'list the active limit orders',
    ExchangeLimitOrderProblem.load,
    (api) => api.orderTriggers.listLimitOrders(),
    (orders) =>
        orders.map(_toLimitOrder).where((order) => order.isOpen).toList(),
  );

  /// The most recent page of limit orders, every status (newest first).
  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> listRecent(
    ExchangeSession session,
  ) => _guard(
    session,
    'list the recent limit orders',
    ExchangeLimitOrderProblem.load,
    (api) => api.orderTriggers.listLimitOrders(),
    (orders) => orders.map(_toLimitOrder).toList(),
  );

  @override
  Future<Result<LimitOrder, ExchangeFailure>> get(
    ExchangeSession session,
    String id,
  ) => _guard(
    session,
    'read the limit order',
    ExchangeLimitOrderProblem.load,
    (api) => api.orderTriggers.getLimitOrder(id),
    _toLimitOrder,
  );

  /// A create that may have reached the exchange without a readable answer,
  /// including a created order the app can't read, is [ExchangeWriteOutcomeUnknownFailure],
  /// never a plain failure the user could retry into a second order. A
  /// refusal keeps its code (see `limitOrderRefusalOf`).
  @override
  Future<Result<LimitOrder, ExchangeWriteFailure>> create(
    ExchangeSession session,
    LimitOrderDraft draft,
  ) async {
    final write =
        switch (await _write<Result<LimitOrder, ExchangeWriteFailure>>(
          session,
          (api) async => Ok(
            await exchangeWrite<bbx.LimitOrder, LimitOrder>(
              'create the limit order',
              () => api.orderTriggers.addLimitOrder(
                limitPrice: draft.limitPrice.toStringAsFixed(
                  draft.currency.decimals,
                ),
                fiatAmount: draft.fiatAmount.toStringAsFixed(
                  draft.currency.decimals,
                ),
                currencyCode: draft.currency.code,
                estimatedBtcAmount: draft.estimatedBtcAmount.toStringAsFixed(8),
                address: draft.address,
              ),
              _toLimitOrder,
            ),
          ),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => writeNotRun<LimitOrder>(failure),
        };
    if (write case Err(failure: ExchangeWriteOutcomeUnknownFailure())) {
      await _journalUnknownCreate(session, draft);
    }
    return write;
  }

  @override
  Future<Result<LimitOrder, ExchangeFailure>> cancel(
    ExchangeSession session,
    String id,
  ) => _guard(
    session,
    'cancel the limit order',
    ExchangeLimitOrderProblem.cancel,
    (api) => api.orderTriggers.cancelLimitOrder(id),
    _toLimitOrder,
  );

  @override
  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll(
    ExchangeSession session,
  ) => _guard(
    session,
    'cancel every limit order',
    ExchangeLimitOrderProblem.cancel,
    (api) => api.orderTriggers.cancelAllLimitOrders(),
    (orders) => orders.map(_toLimitOrder).toList(),
  );

  @override
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    ExchangeSession session,
    String currencyCode,
  ) => _guard(
    session,
    'read the limit order rate',
    ExchangeLimitOrderProblem.load,
    (api) =>
        api.prices.getUserRate(fromCurrency: currencyCode, toCurrency: 'BTC'),
    _toRate,
  );

  static LimitOrder _toLimitOrder(bbx.LimitOrder order) => LimitOrder(
    id: order.limitOrderId,
    number: order.limitOrderNumber ?? '',
    fiatAmount: double.parse(order.fiatAmount),
    currencyCode: order.currencyCode,
    limitPrice: double.parse(order.limitPrice),
    estimatedBtcAmount: double.parse(order.estimatedBtcAmount),
    status: limitOrderStatusFromWire(order.status),
    createdAt: DateTime.parse(order.createdAt),
    expiresAt: DateTime.parse(order.expiresAt),
    executedAt: switch (order.executedAt) {
      final timestamp? => DateTime.parse(timestamp),
      null => null,
    },
    cancelledAt: switch (order.cancelledAt) {
      final timestamp? => DateTime.parse(timestamp),
      null => null,
    },
    executedOrderId: order.executedOrderId,
    address: order.address ?? '',
  );

  /// The rate, validated before [LimitOrderRate] is built: a rate the
  /// server sends without a currency, with a negative precision or with a
  /// price that is not positive is a typed load failure, not an
  /// [ArgumentError] out of the constructor that left the wizard stuck
  /// (LIM-8).
  static LimitOrderRate _toRate(bbx.UserRate rate) {
    final currencyCode = rate.fromCurrency ?? '';
    final precision = rate.precision ?? 2;
    if (currencyCode.isEmpty) {
      throw const _UnreadableRate('no currency');
    }
    if (precision < 0) throw const _UnreadableRate('negative precision');
    final divisor = pow(10, precision);
    final indexPrice = rate.indexPrice / divisor;
    final userPrice = rate.userPrice / divisor;
    if (!indexPrice.isFinite || indexPrice <= 0) {
      throw const _UnreadableRate('index price not positive');
    }
    if (!userPrice.isFinite || userPrice <= 0) {
      throw const _UnreadableRate('user price not positive');
    }
    return LimitOrderRate(
      currencyCode: currencyCode,
      indexPrice: indexPrice,
      userPrice: userPrice,
    );
  }

  Future<Result<T, ExchangeFailure>> _guard<T, R>(
    ExchangeSession session,
    String operation,
    ExchangeLimitOrderProblem fallback,
    Future<Result<R, bbx.BbxFailure>> Function(bbx.Bbx api) request,
    T Function(R value) read,
  ) => _read(
    session,
    fallback,
    (api) => _guarded(api, operation, fallback, request, read),
  );

  Future<Result<T, ExchangeFailure>> _guarded<T, R>(
    bbx.Bbx api,
    String operation,
    ExchangeLimitOrderProblem fallback,
    Future<Result<R, bbx.BbxFailure>> Function(bbx.Bbx api) request,
    T Function(R value) read,
  ) async {
    try {
      return switch (await request(api)) {
        Ok(:final value) => Ok(read(value)),
        Err(:final failure) => Err(_failure(failure, operation, fallback)),
      };
    } on Error {
      rethrow;
    } on _UnreadableRate catch (e, st) {
      log.severe(
        message: 'Unreadable reply to $operation',
        error: e.reason,
        trace: st,
      );
      return Err(ExchangeLimitOrderFailure(fallback, 'unreadable rate'));
    } catch (e, st) {
      final description = e.runtimeType.toString();
      log.severe(
        message: 'Failed to $operation',
        error: description,
        trace: st,
      );
      return Err(ExchangeUnexpectedFailure(description));
    }
  }

  /// The failure for a failed call. A missing credential and an unreadable
  /// one stay distinct; a missing one means the account is unavailable.
  ExchangeFailure _failure(
    bbx.BbxFailure failure,
    String operation,
    ExchangeLimitOrderProblem fallback,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const ExchangeNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return ExchangeLimitOrderFailure(
          fallback,
          'Exchange credential unavailable',
        );
      case bbx.BbxFailure():
        break;
    }
    final description = '$failure';
    log.severe(
      message: 'Failed to $operation',
      error: description,
      trace: StackTrace.current,
    );
    return _mapFailure(failure, description, fallback);
  }

  static ExchangeFailure _mapFailure(
    bbx.BbxFailure failure,
    String description,
    ExchangeLimitOrderProblem fallback,
  ) => switch (failure) {
    bbx.BbxHttpFailure(status: 401) => ExchangeSessionRejectedFailure(
      ExchangeSessionRejection.server,
      description,
    ),
    bbx.BbxRpcFailure(apiCode: 'ERR_ORDTRG_LOMAX429') =>
      ExchangeLimitOrderFailure(
        ExchangeLimitOrderProblem.maximumActive,
        description,
      ),
    bbx.BbxRpcFailure(apiCode: 'ERR_ORDTRG_LO404') => ExchangeLimitOrderFailure(
      ExchangeLimitOrderProblem.notFound,
      description,
    ),
    bbx.BbxRpcFailure(apiCode: 'ERR_ORDTRG_ADDR400') =>
      ExchangeLimitOrderFailure(
        ExchangeLimitOrderProblem.invalidAddress,
        description,
      ),
    bbx.BbxHttpFailure() ||
    bbx.BbxRpcFailure() ||
    bbx.BbxResponseFormatFailure() => ExchangeLimitOrderFailure(
      fallback,
      description,
    ),
    _ => ExchangeUnexpectedFailure(description),
  };
}

/// A rate reply the app can't use. [reason] names the field, never its value.
final class _UnreadableRate implements Exception {
  final String reason;

  const _UnreadableRate(this.reason);
}
