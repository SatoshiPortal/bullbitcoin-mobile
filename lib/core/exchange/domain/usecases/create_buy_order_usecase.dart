import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:flutter/foundation.dart';

class CreateBuyOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateBuyOrderUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<BuyOrder> execute({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required Network network,
    required bool isOwner,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final order = await repo.placeBuyOrder(
        toAddress: toAddress,
        orderAmount: orderAmount,
        currency: currency,
        network: network,
        isOwner: isOwner,
      );
      return order;
    } catch (e) {
      debugPrint('Error in CreateBuyOrderUsecase: $e');
      throw CreateBuyOrderException('$e');
    }
  }
}

class CreateBuyOrderException implements Exception {
  final String message;

  CreateBuyOrderException(this.message);

  @override
  String toString() => '[CreateBuyOrderUsecase]: $message';
}
