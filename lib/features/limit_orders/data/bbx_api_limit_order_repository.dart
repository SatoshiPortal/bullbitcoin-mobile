import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/data/models/limit_order_rate_model.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

typedef _Fallback = LimitOrdersFailure Function(String logMessage);

/// [LimitOrderRepository] on the shared `bbx_api` client.
final class BbxApiLimitOrderRepository implements LimitOrderRepository {
  final BbxApiDatasource _mainnet;
  final BbxApiDatasource _testnet;
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
    (api) async => (await api.orders.listLimitOrders(
      bbx.ListRequest(
        paginator: bbx.Paginator(page: 1, pageSize: 50),
        sortBy: bbx.SortBy.newestFirst(),
        payload: bbx.ListLimitOrdersPayload(),
      ),
    )).unwrap().items.map(toEntity).where((order) => order.isActive).toList(),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> get(String id) => _guard(
    'read the limit order',
    LimitOrdersLoadFailure.new,
    (api) async =>
        toEntity((await api.orders.getLimitOrder(orderId: id)).unwrap()),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> create(
    LimitOrderDraft draft,
  ) => _guard(
    'create the limit order',
    LimitOrderCreationFailure.new,
    (api) async => toEntity(
      (await api.orders.addLimitOrder(
        bbx.CreateLimitOrderPayload(
          fiatAmount: draft.fiatAmount.toStringAsFixed(2),
          currencyCode: draft.currencyCode,
          limitPrice: draft.limitPrice.toStringAsFixed(2),
          estimatedBtcAmount: draft.estimatedBtcAmount.toStringAsFixed(8),
          address: draft.address,
        ),
      )).unwrap(),
    ),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> cancel(String id) => _guard(
    'cancel the limit order',
    LimitOrderCancellationFailure.new,
    (api) async =>
        toEntity((await api.orders.cancelLimitOrder(orderId: id)).unwrap()),
  );

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> cancelAll() => _guard(
    'cancel every limit order',
    LimitOrderCancellationFailure.new,
    (api) async => (await api.orders.cancelAllLimitOrders())
        .unwrap()
        .items
        .map(toEntity)
        .toList(),
  );

  @override
  Future<Result<LimitOrderRate, LimitOrdersFailure>> getRate(
    String currencyCode,
  ) {
    final from = bbx.RateCurrency.values
        .where((c) => c.enumValue == currencyCode)
        .firstOrNull;
    if (from == null) {
      return Future.value(
        Err(LimitOrdersLoadFailure('unsupported currency $currencyCode')),
      );
    }
    return _guard('read the limit order rate', LimitOrdersLoadFailure.new, (
      api,
    ) async {
      final rate = (await api.prices.getUserRate(
        fromCurrency: from,
        toCurrency: bbx.RateCurrency.btc,
      )).unwrap();
      final indexPrice = rate.indexPrice;
      final userPrice = rate.userPrice;
      if (indexPrice == null || userPrice == null) {
        throw const FormatException('Rate without index or user price');
      }
      return LimitOrderRateModel(
        currencyCode: rate.fromCurrency?.enumValue ?? '',
        indexPrice: indexPrice,
        userPrice: userPrice,
        precision: rate.precision ?? 2,
      ).toEntity();
    });
  }

  static LimitOrder toEntity(bbx.LimitOrder order) => LimitOrder(
    id: order.limitOrderId,
    number: order.limitOrderNumber,
    fiatAmount: double.parse(order.fiatAmount),
    currencyCode: order.currencyCode,
    limitPrice: double.parse(order.limitPrice),
    estimatedBtcAmount: double.parse(order.estimatedBtcAmount),
    status: switch (order.status) {
      bbx.LimitOrderStatus.active => LimitOrderStatus.active,
      bbx.LimitOrderStatus.executed => LimitOrderStatus.executed,
      bbx.LimitOrderStatus.cancelled => LimitOrderStatus.cancelled,
      bbx.LimitOrderStatus.expired => LimitOrderStatus.expired,
    },
    createdAt: order.createdAt,
    expiresAt: order.expiresAt,
    executedAt: order.executedAt,
    cancelledAt: order.cancelledAt,
    executedOrderId: order.executedOrderId,
    address: order.address,
  );

  static LimitOrdersFailure mapFailure(
    bbx.ApiError error,
    LimitOrdersFailure Function(String logMessage) fallback,
  ) {
    final logMessage = BbxApiException(error).toString();
    if (error.httpStatus == 401) {
      return LimitOrdersAccountUnavailableFailure(logMessage);
    }
    if (error.rpcErrorData != null) {
      return switch (bbx.BBApiErrorCode.fromString(error.apiErrorCode)) {
        bbx.BBApiErrorCode.errOrdtrgLomax429 => LimitOrdersMaximumActiveFailure(
          logMessage,
        ),
        bbx.BBApiErrorCode.errOrdtrgLo404 => LimitOrderNotFoundFailure(
          logMessage,
        ),
        bbx.BBApiErrorCode.errOrdtrgAddr400 => LimitOrderInvalidAddressFailure(
          logMessage,
        ),
        _ => fallback(logMessage),
      };
    }
    if (error.kind != bbx.ApiErrorKind.unknown ||
        error.isApiKeyMissing ||
        error.httpStatus != null) {
      return LimitOrdersUnexpectedFailure(logMessage);
    }
    return fallback(logMessage);
  }

  Future<Result<T, LimitOrdersFailure>> _guard<T>(
    String operation,
    _Fallback fallback,
    Future<T> Function(BbxApiDatasource api) action,
  ) async {
    try {
      final settings = await _settingsRepository.fetch();
      final api = settings.environment.isTestnet ? _testnet : _mainnet;
      return Ok(await action(api));
    } on Error {
      rethrow;
    } on BbxApiException catch (e, st) {
      log.severe(message: 'Failed to $operation', error: e, trace: st);
      return Err(mapFailure(e.error, fallback));
    } catch (e, st) {
      log.severe(message: 'Failed to $operation', error: e, trace: st);
      return Err(LimitOrdersUnexpectedFailure('$e'));
    }
  }
}
