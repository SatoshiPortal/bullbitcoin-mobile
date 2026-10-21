import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';

class ListAllOrdersUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  ListAllOrdersUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  Future<List<Order>> execute({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final orders = await repo.getOrders(
        limit: limit,
        offset: offset,
        type: type,
      );
      return switch (orders) {
        Ok(:final value) => value,
        Err(:final failure) => throw ListAllOrdersException(
          'Exchange order history unavailable: ${failure.runtimeType}',
        ),
      };
    } on ListAllOrdersException {
      rethrow;
    } on Exception catch (e) {
      log.warning('Exchange order unavailable: ${e.runtimeType}');
      throw ListAllOrdersException(
        'Exchange order history unavailable: ${e.runtimeType}',
      );
    }
  }
}

class ListAllOrdersException extends BullException {
  ListAllOrdersException(super.message);
}
