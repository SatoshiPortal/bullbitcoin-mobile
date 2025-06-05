import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:flutter/foundation.dart';

class ListAllOrdersUsecase {
  final ExchangeOrderRepository _exchangeOrderRepository;

  ListAllOrdersUsecase({
    required ExchangeOrderRepository exchangeOrderRepository,
  }) : _exchangeOrderRepository = exchangeOrderRepository;

  Future<List<Order>> execute({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final orders = await _exchangeOrderRepository.getOrders(
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
