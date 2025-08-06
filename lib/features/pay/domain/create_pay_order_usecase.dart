import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class PlacePayOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  PlacePayOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<FiatPaymentOrder> execute({
    required OrderAmount orderAmount,
    required String recipientId,
    required String paymentProcessor,
    required bool isLiquid,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final network =
          isLiquid ? OrderBitcoinNetwork.liquid : OrderBitcoinNetwork.bitcoin;
      final order = await repo.placePayOrder(
        orderAmount: orderAmount,
        recipientId: recipientId,
        paymentProcessor: paymentProcessor,
        network: network,
      );
      return order;
    } on PayError {
      rethrow;
    } catch (e) {
      log.severe('Error in PlacePayOrderUsecase: $e');
      throw PayError.unexpected(message: '$e');
    }
  }
}
