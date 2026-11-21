import 'dart:math';

import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

typedef _Fallback = LimitOrdersFailure Function(String logMessage);

/// [LimitOrderRepository] on the `bbx_api` package.
final class BbxApiLimitOrderRepository implements LimitOrderRepository {
  final bbx.BbxApiClient _mainnet;
  final bbx.BbxApiClient _testnet;
  final SettingsRepository _settingsRepository;

  const BbxApiLimitOrderRepository({
    required this._mainnet,
    required this._testnet,
    required this._settingsRepository,
  });

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> listActive() => _guard(
    'list the active limit orders',
    LimitOrdersLoadFailure.new,
    (api) async => (await api.orderTriggers.listLimitOrders())
        .map(_toLimitOrder)
        .where((order) => order.isActive)
        .toList(),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> get(String id) => _guard(
    'read the limit order',
    LimitOrdersLoadFailure.new,
    (api) async => _toLimitOrder(await api.orderTriggers.getLimitOrder(id)),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> create(
    LimitOrderDraft draft,
  ) => _guard(
    'create the limit order',
    LimitOrderCreationFailure.new,
    (api) async => _toLimitOrder(
      await api.orderTriggers.addLimitOrder(
        limitPrice: draft.limitPrice.toStringAsFixed(2),
        fiatAmount: draft.fiatAmount.toStringAsFixed(2),
        currencyCode: draft.currencyCode,
        estimatedBtcAmount: draft.estimatedBtcAmount.toStringAsFixed(8),
        address: draft.address,
      ),
    ),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> cancel(String id) => _guard(
    'cancel the limit order',
    LimitOrderCancellationFailure.new,
    (api) async => _toLimitOrder(await api.orderTriggers.cancelLimitOrder(id)),
  );

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> cancelAll() => _guard(
    'cancel every limit order',
    LimitOrderCancellationFailure.new,
    (api) async => (await api.orderTriggers.cancelAllLimitOrders())
        .map(_toLimitOrder)
        .toList(),
  );

  @override
  Future<Result<LimitOrderRate, LimitOrdersFailure>> getRate(
    String currencyCode,
  ) => _guard(
    'read the limit order rate',
    LimitOrdersLoadFailure.new,
    (api) async => _toRate(
      await api.prices.getUserRate(
        fromCurrency: currencyCode,
        toCurrency: 'BTC',
      ),
    ),
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

  Future<Result<T, LimitOrdersFailure>> _guard<T>(
    String operation,
    _Fallback fallback,
    Future<T> Function(bbx.BbxApiClient api) action,
  ) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.activeNetwork.name),
        NetworkCapability.exchange,
      )) {
        return const Err(LimitOrdersUnsupportedNetworkFailure());
      }
      final api = settings.environment.requireHistoricalTestnet()
          ? _testnet
          : _mainnet;
      return Ok(await action(api));
    } on Error {
      rethrow;
    } catch (e, st) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return Err(
          refusal.isUnauthenticated
              ? const LimitOrdersAccountUnavailableFailure()
              : fallback('Exchange credential unavailable'),
        );
      }
      final description = _describe(e);
      log.severe(
        message: 'Failed to $operation',
        error: description,
        trace: st,
      );
      return Err(_mapFailure(e, description, fallback));
    }
  }

  static LimitOrdersFailure _mapFailure(
    Object e,
    String description,
    _Fallback fallback,
  ) => switch (e) {
    DioException(response: Response(statusCode: 401)) =>
      LimitOrdersAccountUnavailableFailure(description),
    bbx.BbxApiRpcException(apiCode: 'ERR_ORDTRG_LOMAX429') =>
      LimitOrdersMaximumActiveFailure(description),
    bbx.BbxApiRpcException(apiCode: 'ERR_ORDTRG_LO404') =>
      LimitOrderNotFoundFailure(description),
    bbx.BbxApiRpcException(apiCode: 'ERR_ORDTRG_ADDR400') =>
      LimitOrderInvalidAddressFailure(description),
    bbx.BbxApiException() => fallback(description),
    _ => LimitOrdersUnexpectedFailure(description),
  };

  /// A JSON-RPC error message can quote the request, so only its codes are
  /// kept.
  static String _describe(Object e) => switch (e) {
    bbx.BbxApiRpcException(:final code, :final apiCode) =>
      'BbxApiRpcException(code: $code, apiCode: $apiCode)',
    DioException(:final type, :final response) =>
      'DioException(${type.name}, status: ${response?.statusCode})',
    _ => e.runtimeType.toString(),
  };
}
