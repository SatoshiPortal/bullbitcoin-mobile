import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CreateSellOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateSellOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<SellOrder> execute({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final order = await repo.placeSellOrder(
        orderAmount: orderAmount,
        currency: currency,
        network: network,
      );
      return order;
    } on SellError {
      rethrow;
    } catch (e) {
      log.severe('Error in CreateSellOrderUsecase: $e');
      throw SellError.unexpected(message: '$e');
    }
  }
}
