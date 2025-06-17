import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class AccelerateBuyOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  AccelerateBuyOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<BuyOrder> execute(String orderId) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final order = await repo.accelerateBuyOrder(orderId);
      return order;
    } catch (e) {
      log.severe('Error in AccelerateBuyOrderUsecase: $e');
      throw AccelerateBuyOrderException('$e');
    }
  }
}

class AccelerateBuyOrderException implements Exception {
  final String message;

  AccelerateBuyOrderException(this.message);

  @override
  String toString() => '[AccelerateBuyOrderUsecase]: $message';
}
