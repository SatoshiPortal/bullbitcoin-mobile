import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class LabelExchangeOrdersUsecase {
  final LabelsFacade _labelsFacade;
  final ListAllOrdersUsecase _listAllOrdersUsecase;
  final WalletTransactionRepository _walletTransactionRepository;

  LabelExchangeOrdersUsecase({
    required this._labelsFacade,
    required this._listAllOrdersUsecase,
    required this._walletTransactionRepository,
  });

  /// Labels are written only by an explicit order-completion event. History
  /// reads must never turn unverified server data into privileged labels.
  Future<void> execute({
    List<Order>? orders,
    bool explicitCompletion = false,
  }) async {
    if (!explicitCompletion) return;
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
          if (order.orderStatus != OrderStatus.completed ||
              (order.orderType != OrderType.buy &&
                  order.orderType != OrderType.sell)) {
            continue;
          }
          final isBuyOrder = order is BuyOrder;
          final systemLabel = isBuyOrder
              ? LabelSystem.exchangeBuy.label
              : LabelSystem.exchangeSell.label;

          // The address and transaction id come from the exchange. A system
          // label is privileged (the user cannot remove it), so it is only
          // ever written on a reference this wallet actually owns — never on
          // whatever the server reports.
          final transactionId = order.transactionId;
          if (transactionId == null) continue;
          final walletTransactions = await _walletTransactionRepository
              .getWalletTransactions(txId: transactionId);
          if (walletTransactions.isEmpty) {
            log.warning(
              '$LabelExchangeOrdersUsecase order ${order.orderId} references '
              'a transaction this wallet does not have; not labeling it',
            );
            continue;
          }
          final ownedAddresses = <String>{
            for (final walletTransaction in walletTransactions)
              for (final output in walletTransaction.outputs)
                if (output.isOwn) ?output.address,
          };

          if (isBuyOrder && ownedAddresses.contains(order.toAddress)) {
            final label = NewLabel.addr(
              address: order.toAddress!,
              label: systemLabel,
              origin: null,
            );
            if (existingLabelReferences.add((label.label, label.reference))) {
              labels.add(label);
            }
          }

          final label = NewLabel.tx(
            transactionId: transactionId,
            label: systemLabel,
            origin: null,
          );
          if (existingLabelReferences.add((label.label, label.reference))) {
            labels.add(label);
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
