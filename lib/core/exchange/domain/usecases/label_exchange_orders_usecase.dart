import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/labels.dart';

class LabelExchangeOrdersUsecase {
  final FetchAllLabelsUsecase _fetchAllLabelsUsecase;
  final StoreLabelsUsecase _storeLabelsUsecase;
  final ListAllOrdersUsecase _listAllOrdersUsecase;

  LabelExchangeOrdersUsecase({
    required FetchAllLabelsUsecase fetchAllLabelsUsecase,
    required StoreLabelsUsecase storeLabelsUsecase,
    required ListAllOrdersUsecase listAllOrdersUsecase,
  }) : _fetchAllLabelsUsecase = fetchAllLabelsUsecase,
       _storeLabelsUsecase = storeLabelsUsecase,
       _listAllOrdersUsecase = listAllOrdersUsecase;

  Future<void> execute() async {
    try {
      final hasExchangeLabels = await _hasExistingExchangeSystemLabels();
      if (hasExchangeLabels) return; // orders likely already labeled

      final orders = await _listAllOrdersUsecase.execute();
      if (orders.isEmpty) return; // no orders to label

      log.config('$LabelExchangeOrdersUsecase is labeling exchange orders');

      final labels = <Label>[];
      for (final order in orders) {
        try {
          final isBuyOrder = order is BuyOrder;
          final systemLabel = isBuyOrder
              ? LabelSystem.exchangeBuy.label
              : LabelSystem.exchangeSell.label;

          if (isBuyOrder && order.toAddress != null) {
            final label = Label.addr(
              address: order.toAddress!,
              label: systemLabel,
              origin: null,
            );
            labels.add(label);
          }

          if (order.transactionId != null) {
            final label = Label.tx(
              transactionId: order.transactionId!,
              label: systemLabel,
              origin: null,
            );
            labels.add(label);
          }
        } catch (e) {
          log.warning('$LabelExchangeOrdersUsecase order ${order.orderId}: $e');
        }
      }

      await _storeLabelsUsecase.execute(labels);

      log.fine(
        '$LabelExchangeOrdersUsecase labeled ${orders.length} exchange orders',
      );
    } catch (e) {
      log.severe('$LabelExchangeOrdersUsecase: $e');
    }
  }

  Future<bool> _hasExistingExchangeSystemLabels() async {
    try {
      final allLabels = await _fetchAllLabelsUsecase.execute();
      return allLabels.any(
        (label) =>
            label.label == LabelSystem.exchangeBuy.label ||
            label.label == LabelSystem.exchangeSell.label,
      );
    } catch (e) {
      log.warning('$LabelExchangeOrdersUsecase: $e');
      return false;
    }
  }
}
