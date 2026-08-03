import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';

/// Fetches the latest state of a sell order while polling.

class GetSellOrderStatusUsecase {
  final GetOrderUsecase _getOrderUsecase;

  GetSellOrderStatusUsecase({required this._getOrderUsecase});

  @useResult
  Future<Result<SellOrder, SellFailure>> execute({
    required String orderId,
  }) async {
    try {
      final order = await _getOrderUsecase.execute(orderId: orderId);
      if (order is! SellOrder) {
        return const Err(
          SellUnexpectedFailure('expected a SellOrder while polling'),
        );
      }
      return Ok(order);
    } catch (e, st) {
      log.severe(message: 'sell order status poll failed', error: e, trace: st);
      return Err(SellUnexpectedFailure(e.toString()));
    }
  }
}
