import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:flutter/foundation.dart';

class ListAllOrdersUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  ListAllOrdersUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
       _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
       _settingsRepository = settingsRepository;

  Future<List<Order>> execute({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeOrderRepository
              : _mainnetExchangeOrderRepository;
      final orders = await repo.getOrders(
        limit: limit,
        offset: offset,
        type: type,
      );
      return orders;
    } catch (e) {
      debugPrint('Error in ListAllOrdersUsecase: $e');
      throw ListAllOrdersException('$e');
    }
  }
}

class ListAllOrdersException implements Exception {
  final String message;

  ListAllOrdersException(this.message);

  @override
  String toString() => '[ListAllOrdersUsecase]: $message';
}
