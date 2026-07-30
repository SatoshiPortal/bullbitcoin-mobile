import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class LabelExchangeOrdersUsecase {
  final LabelsFacade _labelsFacade;
  final ListAllOrdersUsecase _listAllOrdersUsecase;

  LabelExchangeOrdersUsecase({
    required this._labelsFacade,
    required this._listAllOrdersUsecase,
  });

  Future<void> execute({List<Order>? orders}) async {
    try {
      final ordersToLabel = orders ?? await _listAllOrdersUsecase.execute();
      if (ordersToLabel.isEmpty) return;

      final existingLabels = await _labelsFacade.fetchAll();
      final existingLabelReferences = {
        for (final label in existingLabels) (label.label, label.reference),
      };

      log.config('$LabelExchangeOrdersUsecase is labeling exchange orders');

      final labels = <NewLabel>[];
      for (final order in ordersToLabel) {
        try {
          final isBuyOrder = order is BuyOrder;
          final systemLabel = isBuyOrder
              ? LabelSystem.exchangeBuy.label
              : LabelSystem.exchangeSell.label;

          if (isBuyOrder && order.toAddress != null) {
            final label = NewLabel.addr(
              address: order.toAddress!,
              label: systemLabel,
              origin: null,
            );
            if (existingLabelReferences.add((label.label, label.reference))) {
              labels.add(label);
            }
          }

          if (order.transactionId != null) {
            final label = NewLabel.tx(
              transactionId: order.transactionId!,
              label: systemLabel,
              origin: null,
            );
            if (existingLabelReferences.add((label.label, label.reference))) {
              labels.add(label);
            }
          }
        } catch (e) {
          log.warning('$LabelExchangeOrdersUsecase order ${order.orderId}: $e');
        }
      }

      for (final label in labels) {
        await _labelsFacade.store(label);
      }

      log.fine(
        '$LabelExchangeOrdersUsecase stored ${labels.length} exchange labels',
      );
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
    }
  }
}
