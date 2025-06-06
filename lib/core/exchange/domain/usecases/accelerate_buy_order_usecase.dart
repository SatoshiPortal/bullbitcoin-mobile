import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:flutter/foundation.dart';

class AccelerateBuyOrderUsecase {
  final ExchangeOrderRepository _exchangeOrderRepository;

  AccelerateBuyOrderUsecase({
    required ExchangeOrderRepository exchangeOrderRepository,
  }) : _exchangeOrderRepository = exchangeOrderRepository;

  Future<BuyOrder> execute(String orderId) async {
    try {
      final order = await _exchangeOrderRepository.accelerateBuyOrder(orderId);
      return order;
    } catch (e) {
      debugPrint('Error in AccelerateBuyOrderUsecase: $e');
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
