import 'dart:math';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

typedef _Fallback = LimitOrdersFailure Function(String logMessage);

/// [LimitOrderRepository] on the `bbx_api` package.
final class BbxApiLimitOrderRepository implements LimitOrderRepository {
  final bbx.Bbx _mainnet;
  final bbx.Bbx _testnet;
  final Preferences _settingsRepository;

  const BbxApiLimitOrderRepository({
    required this._mainnet,
    required this._testnet,
    required this._settingsRepository,
  });

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> listActive() => _guard(
    'list the active limit orders',
    LimitOrdersLoadFailure.new,
    (api) => api.orderTriggers.listLimitOrders(),
    (orders) =>
        orders.map(_toLimitOrder).where((order) => order.isActive).toList(),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> get(String id) => _guard(
    'read the limit order',
    LimitOrdersLoadFailure.new,
    (api) => api.orderTriggers.getLimitOrder(id),
    _toLimitOrder,
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> create(
    LimitOrderDraft draft,
  ) => _guard(
    'create the limit order',
    LimitOrderCreationFailure.new,
    (api) => api.orderTriggers.addLimitOrder(
      limitPrice: draft.limitPrice.toStringAsFixed(2),
      fiatAmount: draft.fiatAmount.toStringAsFixed(2),
      currencyCode: draft.currencyCode,
      estimatedBtcAmount: draft.estimatedBtcAmount.toStringAsFixed(8),
      address: draft.address,
    ),
    _toLimitOrder,
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> cancel(String id) => _guard(
    'cancel the limit order',
    LimitOrderCancellationFailure.new,
    (api) => api.orderTriggers.cancelLimitOrder(id),
    _toLimitOrder,
  );

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> cancelAll() => _guard(
    'cancel every limit order',
    LimitOrderCancellationFailure.new,
    (api) => api.orderTriggers.cancelAllLimitOrders(),
    (orders) => orders.map(_toLimitOrder).toList(),
  );

  @override
  Future<Result<LimitOrderRate, LimitOrdersFailure>> getRate(
    String currencyCode,
  ) => _guard(
    'read the limit order rate',
    LimitOrdersLoadFailure.new,
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

  Future<Result<T, LimitOrdersFailure>> _guard<T, R>(
    String operation,
    _Fallback fallback,
    Future<Result<R, bbx.BbxFailure>> Function(bbx.Bbx api) request,
    T Function(R value) read,
  ) async {
    try {
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.activeNetwork.name),
        NetworkCapability.exchange,
      )) {
        return const Err(LimitOrdersUnsupportedNetworkFailure());
      }
      final api = settings.environment.requireHistoricalTestnet()
          ? _testnet
          : _mainnet;
      return switch (await request(api)) {
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
      return Err(LimitOrdersUnexpectedFailure(description));
    }
  }

  /// The failure for a failed call. A missing credential and an unreadable
  /// one stay distinct; a missing one means the account is unavailable.
  LimitOrdersFailure _failure(
    bbx.BbxFailure failure,
    String operation,
    _Fallback fallback,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const LimitOrdersAccountUnavailableFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return fallback('Exchange credential unavailable');
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

  static LimitOrdersFailure _mapFailure(
    bbx.BbxFailure failure,
    String description,
    _Fallback fallback,
  ) => switch (failure) {
    bbx.BbxHttpFailure(status: 401) => LimitOrdersAccountUnavailableFailure(
      description,
    ),
    bbx.BbxRpcFailure(apiCode: 'ERR_ORDTRG_LOMAX429') =>
      LimitOrdersMaximumActiveFailure(description),
    bbx.BbxRpcFailure(apiCode: 'ERR_ORDTRG_LO404') => LimitOrderNotFoundFailure(
      description,
    ),
    bbx.BbxRpcFailure(apiCode: 'ERR_ORDTRG_ADDR400') =>
      LimitOrderInvalidAddressFailure(description),
    bbx.BbxHttpFailure() ||
    bbx.BbxRpcFailure() ||
    bbx.BbxResponseFormatFailure() => fallback(description),
    _ => LimitOrdersUnexpectedFailure(description),
  };

  /// A JSON-RPC error message can quote the request, so only its codes are
  /// kept.
  static String _describe(bbx.BbxFailure failure) => switch (failure) {
    bbx.BbxRpcFailure(:final code, :final apiCode) =>
      'BbxRpcFailure(code: $code, apiCode: $apiCode)',
    bbx.BbxHttpFailure(:final status) => 'BbxHttpFailure(status: $status)',
    bbx.BbxTimeoutFailure(:final kind) => 'BbxTimeoutFailure(${kind.name})',
    bbx.BbxResponseFormatFailure(:final reason) =>
      'BbxResponseFormatFailure($reason)',
    _ => failure.runtimeType.toString(),
  };
}
