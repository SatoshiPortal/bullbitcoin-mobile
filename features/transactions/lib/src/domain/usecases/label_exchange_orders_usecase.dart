import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:transactions/src/domain/repositories/wallet_transaction_repository.dart';
import 'package:labels/labels.dart';

class LabelExchangeOrdersUsecase {
  final Labels _labelsFacade;
  final WalletTransactionRepository _walletTransactionRepository;

  LabelExchangeOrdersUsecase({
    required this._labelsFacade,
    required this._walletTransactionRepository,
  });

  /// Labels are written only by an explicit order-completion event. History
  /// reads must never turn unverified server data into privileged labels.
  Future<void> execute({
    required List<Order> orders,
    bool explicitCompletion = false,
  }) async {
    if (!explicitCompletion) return;
    try {
      if (orders.isEmpty) return;

      final existingLabels = (await _labelsFacade.fetch()).fold(
        (labels) => labels,
        (_) => const <Label>[],
      );
      final existingLabelReferences = {
        for (final label in existingLabels) (label.label, label.reference),
      };

      log.config('$LabelExchangeOrdersUsecase is labeling exchange orders');

      final labels = <NewLabel>[];
      for (final order in orders) {
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
          final ownedHistory = await _walletTransactionRepository
              .getWalletTransactions(txId: transactionId);
          final walletTransactions = switch (ownedHistory) {
            Ok(:final value) => value,
            Err() => const <WalletTransaction>[],
          };
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
