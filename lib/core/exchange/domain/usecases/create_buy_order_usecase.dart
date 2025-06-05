import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:flutter/foundation.dart';

class CreateBuyOrderUsecase {
  final ExchangeOrderRepository _exchangeOrderRepository;

  CreateBuyOrderUsecase({
    required ExchangeOrderRepository exchangeOrderRepository,
  }) : _exchangeOrderRepository = exchangeOrderRepository;

  Future<BuyOrder> execute({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required Network network,
    required String isOwner,
  }) async {
    try {
      final order = await _exchangeOrderRepository.placeBuyOrder(
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