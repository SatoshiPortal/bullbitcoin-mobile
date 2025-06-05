import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:flutter/foundation.dart';

class RefreshBuyOrderUsecase {
  final ExchangeOrderRepository _exchangeOrderRepository;

  RefreshBuyOrderUsecase({
    required ExchangeOrderRepository exchangeOrderRepository,
  }) : _exchangeOrderRepository = exchangeOrderRepository;

  Future<BuyOrder> execute({
    required String orderId,
  }) async {
    try {
      final order = await _exchangeOrderRepository.refreshBuyOrder(orderId);
      return order;
    } catch (e) {
      debugPrint('Error in RefreshBuyOrderUsecase: $e');
      throw RefreshBuyOrderException('$e');
    }
  }
}

class RefreshBuyOrderException implements Exception {
  final String message;

  RefreshBuyOrderException(this.message);

  @override
  String toString() => '[RefreshBuyOrderUsecase]: $message';
}