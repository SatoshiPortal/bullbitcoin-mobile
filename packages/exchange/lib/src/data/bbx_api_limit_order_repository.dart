import 'dart:math';

import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/limit_order.dart';
import '../domain/entities/limit_order_draft.dart';
import '../domain/entities/limit_order_rate.dart';
import '../domain/exchange_failure.dart';

final class BbxApiLimitOrderRepository {
  final bbx.Bbx _api;

  const BbxApiLimitOrderRepository(this._api);

  Future<Result<List<LimitOrder>, ExchangeFailure>> listActive() => _guard(
    'list the active limit orders',
    ExchangeLimitOrderProblem.load,
    (api) => api.orderTriggers.listLimitOrders(),
    (orders) =>
        orders.map(_toLimitOrder).where((order) => order.isActive).toList(),
  );

  Future<Result<LimitOrder, ExchangeFailure>> get(String id) => _guard(
    'read the limit order',
    ExchangeLimitOrderProblem.load,
    (api) => api.orderTriggers.getLimitOrder(id),
    _toLimitOrder,
  );

  Future<Result<LimitOrder, ExchangeFailure>> create(LimitOrderDraft draft) =>
      _guard(
        'create the limit order',
        ExchangeLimitOrderProblem.create,
        (api) => api.orderTriggers.addLimitOrder(
          limitPrice: draft.limitPrice.toStringAsFixed(draft.currency.decimals),
          fiatAmount: draft.fiatAmount.toStringAsFixed(draft.currency.decimals),
          currencyCode: draft.currency.code,
          estimatedBtcAmount: draft.estimatedBtcAmount.toStringAsFixed(8),
          address: draft.address,
        ),
        _toLimitOrder,
      );

  Future<Result<LimitOrder, ExchangeFailure>> cancel(String id) => _guard(
    'cancel the limit order',
    ExchangeLimitOrderProblem.cancel,
    (api) => api.orderTriggers.cancelLimitOrder(id),
    _toLimitOrder,
  );

  Future<Result<List<LimitOrder>, ExchangeFailure>> cancelAll() => _guard(
    'cancel every limit order',
    ExchangeLimitOrderProblem.cancel,
    (api) => api.orderTriggers.cancelAllLimitOrders(),
    (orders) => orders.map(_toLimitOrder).toList(),
  );

  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    String currencyCode,
  ) => _guard(
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
    status: LimitOrderStatus.fromValue(order.status),
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

  static LimitOrderRate _toRate(bbx.UserRate rate) {
    final divisor = pow(10, rate.precision ?? 2);
    return LimitOrderRate(
      currencyCode: rate.fromCurrency ?? '',
      indexPrice: rate.indexPrice / divisor,
      userPrice: rate.userPrice / divisor,
    );
  }

  Future<Result<T, ExchangeFailure>> _guard<T, R>(
    String operation,
    ExchangeLimitOrderProblem fallback,
    Future<Result<R, bbx.BbxFailure>> Function(bbx.Bbx api) request,
    T Function(R value) read,
  ) async {
    try {
      return switch (await request(_api)) {
        Ok(:final value) => Ok(read(value)),
        Err(:final failure) => Err(_failure(failure, operation, fallback)),
      };
    } on Error {
      rethrow;
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
    final description = _describe(failure);
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

  /// A JSON-RPC error message can quote the request, so only its codes are
  /// kept.
  static String _describe(bbx.BbxFailure failure) => switch (failure) {
    bbx.BbxRpcFailure(:final code, :final apiCode) =>
      'BbxRpcFailure(code: $code, apiCode: $apiCode)'
          '${failure.requestIdLabel}',
    bbx.BbxHttpFailure(:final status) => 'BbxHttpFailure(status: $status)',
    bbx.BbxTimeoutFailure(:final kind) => 'BbxTimeoutFailure(${kind.name})',
    bbx.BbxResponseFormatFailure(:final reason) =>
      'BbxResponseFormatFailure($reason)',
    _ => failure.runtimeType.toString(),
  };
}
