import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:flutter/foundation.dart';

class ConfirmBuyOrderUsecase {
  final ExchangeOrderRepository _exchangeOrderRepository;

  ConfirmBuyOrderUsecase({
    required ExchangeOrderRepository exchangeOrderRepository,
  }) : _exchangeOrderRepository = exchangeOrderRepository;

  Future<BuyOrder> execute({
    required String orderId,
  }) async {
    try {
      final order = await _exchangeOrderRepository.confirmBuyOrder(orderId);
      return order;
    } catch (e) {
      debugPrint('Error in ConfirmBuyOrderUsecase: $e');
      throw ConfirmBuyOrderException('$e');
    }
  }
}

class ConfirmBuyOrderException implements Exception {
  final String message;

  ConfirmBuyOrderException(this.message);

  @override
  String toString() => '[ConfirmBuyOrderUsecase]: $message';
}