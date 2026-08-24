import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';

/// Public contract of the transactions feature for other features.
class TransactionsFacade {
  final LabelExchangeOrdersUsecase _labelExchangeOrdersUsecase;

  TransactionsFacade({required this._labelExchangeOrdersUsecase});

  /// Writes privileged exchange labels for orders that explicitly completed.
  /// History reads must never trigger this (issue #2624): only call it from
  /// an explicit order-completion event.
  Future<void> labelCompletedExchangeOrders(List<Order> orders) =>
      _labelExchangeOrdersUsecase.execute(
        orders: orders,
        explicitCompletion: true,
      );
}
