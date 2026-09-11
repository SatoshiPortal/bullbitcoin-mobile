import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Reads a pay order by id and refuses anything that is not one.
///
/// The shared use-case returns the whole [Order] family, so the narrowing that
/// used to be a bare `is!` check plus a throw lives here instead.
class GetPayOrderUsecase {
  final GetOrderUsecase _getOrderUsecase;

  const GetPayOrderUsecase({required this._getOrderUsecase});

  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
    required String orderId,
  }) async {
    final Order order;
    try {
      order = await _getOrderUsecase.execute(orderId: orderId);
    } catch (e, st) {
      log.severe(message: 'Failed to read the pay order', error: e, trace: st);
      return Err(PayUnexpectedFailure('$e'));
    }

    if (order is! FiatPaymentOrder) {
      log.severe(
        error:
            'Expected a FiatPaymentOrder for $orderId but received '
            '${order.runtimeType}',
        trace: StackTrace.current,
      );
      return const Err(
        PayUnexpectedFailure('order is not a fiat payment order'),
      );
    }

    return Ok(order);
  }
}
