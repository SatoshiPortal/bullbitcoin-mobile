import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/domain/label_address_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_transaction_usecase.dart';
import 'package:bb_mobile/core/labels/label_system.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class LabelExchangeOrdersUsecase {
  final LabelDatasource _labelDatasource;
  final LabelTransactionUsecase _labelTransactionUsecase;
  final LabelAddressUsecase _labelAddressUsecase;
  final ListAllOrdersUsecase _listAllOrdersUsecase;

  LabelExchangeOrdersUsecase({
    required LabelDatasource labelDatasource,
    required LabelTransactionUsecase labelTransactionUsecase,
    required LabelAddressUsecase labelAddressUsecase,
    required ListAllOrdersUsecase listAllOrdersUsecase,
  }) : _labelDatasource = labelDatasource,
       _labelTransactionUsecase = labelTransactionUsecase,
       _labelAddressUsecase = labelAddressUsecase,
       _listAllOrdersUsecase = listAllOrdersUsecase;

  Future<void> execute() async {
    try {
      final hasExchangeLabels = await _hasExistingExchangeSystemLabels();
      if (hasExchangeLabels) return; // orders likely already labeled

      final orders = await _listAllOrdersUsecase.execute();
      if (orders.isEmpty) return; // no orders to label

      log.config('$LabelExchangeOrdersUsecase is labeling exchange orders');

      for (final order in orders) {
        try {
          final isBuyOrder = order is BuyOrder;
          final systemLabel = isBuyOrder
              ? LabelSystem.exchangeBuy.label
              : LabelSystem.exchangeSell.label;

          if (isBuyOrder && order.toAddress != null) {
            await _labelAddressUsecase.execute(
              address: order.toAddress!,
              label: systemLabel,
              origin: null,
            );
          }

          if (order.transactionId != null) {
            await _labelTransactionUsecase.execute(
              txid: order.transactionId!,
              label: systemLabel,
              origin: null,
            );
          }
        } catch (e) {
          log.warning('$LabelExchangeOrdersUsecase order ${order.orderId}: $e');
        }
      }

      log.fine(
        '$LabelExchangeOrdersUsecase labeled ${orders.length} exchange orders',
      );
    } catch (e) {
      log.severe('$LabelExchangeOrdersUsecase: $e');
    }
  }

  Future<bool> _hasExistingExchangeSystemLabels() async {
    try {
      final allLabels = await _labelDatasource.fetchAll();
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
