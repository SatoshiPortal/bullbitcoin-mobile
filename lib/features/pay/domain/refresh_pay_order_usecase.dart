import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class RefreshPayOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshPayOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<FiatPaymentOrder> execute({required String orderId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final order = await repo.refreshPayOrder(orderId);
      return order;
    } catch (e) {
      log.severe('Error in RefreshPayOrderUsecase: $e');
      if (e is PayError) {
        rethrow;
      }
      throw PayError.unexpected(message: '$e');
    }
  }
}
