import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/data/datasources/limit_orders_api_datasource.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

typedef _Fallback = LimitOrdersFailure Function(String logMessage);

final class LimitOrderRepositoryImpl implements LimitOrderRepository {
  final LimitOrdersApiDatasource _mainnetDatasource;
  final LimitOrdersApiDatasource _testnetDatasource;
  final SettingsRepository _settingsRepository;

  const LimitOrderRepositoryImpl(
    this._mainnetDatasource,
    this._testnetDatasource,
    this._settingsRepository,
  );

  Future<LimitOrdersApiDatasource> get _datasource async {
    final settings = await _settingsRepository.fetch();
    return settings.environment.isTestnet
        ? _testnetDatasource
        : _mainnetDatasource;
  }

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> listActive() => _guard(
    'list the active limit orders',
    LimitOrdersLoadFailure.new,
    (datasource) async => (await datasource.listActive())
        .map((m) => m.toEntity())
        .where((order) => order.isActive)
        .toList(),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> get(String id) => _guard(
    'read the limit order',
    LimitOrdersLoadFailure.new,
    (datasource) async => (await datasource.get(id)).toEntity(),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> create(
    LimitOrderDraft draft,
  ) => _guard(
    'create the limit order',
    LimitOrderCreationFailure.new,
    (datasource) async => (await datasource.create(draft)).toEntity(),
  );

  @override
  Future<Result<LimitOrder, LimitOrdersFailure>> cancel(String id) => _guard(
    'cancel the limit order',
    LimitOrderCancellationFailure.new,
    (datasource) async => (await datasource.cancel(id)).toEntity(),
  );

  @override
  Future<Result<List<LimitOrder>, LimitOrdersFailure>> cancelAll() => _guard(
    'cancel every limit order',
    LimitOrderCancellationFailure.new,
    (datasource) async =>
        (await datasource.cancelAll()).map((m) => m.toEntity()).toList(),
  );

  @override
  Future<Result<LimitOrderRate, LimitOrdersFailure>> getRate(
    String currencyCode,
  ) => _guard(
    'read the limit order rate',
    LimitOrdersLoadFailure.new,
    (datasource) async => (await datasource.getRate(currencyCode)).toEntity(),
  );

  Future<Result<T, LimitOrdersFailure>> _guard<T>(
    String operation,
    _Fallback fallback,
    Future<T> Function(LimitOrdersApiDatasource datasource) action,
  ) async {
    try {
      return Ok(await action(await _datasource));
    } on Error {
      rethrow;
    } catch (e, st) {
      log.severe(message: 'Failed to $operation', error: e, trace: st);
      return Err(_mapFailure(e, fallback));
    }
  }

  LimitOrdersFailure _mapFailure(Object e, _Fallback fallback) {
    if (e is DioException && e.response?.statusCode == 401) {
      return LimitOrdersAccountUnavailableFailure('$e');
    }
    if (e is LimitOrdersApiException) {
      return switch (e.code) {
        'ERR_ORDTRG_LOMAX429' => LimitOrdersMaximumActiveFailure('$e'),
        'ERR_ORDTRG_LO404' => LimitOrderNotFoundFailure('$e'),
        'ERR_ORDTRG_ADDR400' => LimitOrderInvalidAddressFailure('$e'),
        _ => fallback('$e'),
      };
    }
    return LimitOrdersUnexpectedFailure('$e');
  }
}
