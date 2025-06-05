import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:flutter/foundation.dart';

class GetOrderUsecase {
  final ExchangeOrderRepository _exchangeOrderRepository;

  GetOrderUsecase({
    required ExchangeOrderRepository exchangeOrderRepository,
  }) : _exchangeOrderRepository = exchangeOrderRepository;

  Future<Order> execute({
    required String orderId,
  }) async {
    try {
      final order = await _exchangeOrderRepository.getOrder(orderId);
      return order;
    } catch (e) {
      debugPrint('Error in GetOrderUsecase: $e');
      throw GetOrderException('$e');
    }
  }
}

class GetOrderException implements Exception {
  final String message;

  GetOrderException(this.message);

  @override
  String toString() => '[GetOrderUsecase]: $message';
}