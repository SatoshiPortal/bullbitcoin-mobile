import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/tx_list_item.dart' as core;
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Feature-side entry point of the core row: maps a [Transaction] to a
/// [core.TxListItemData] and delegates the rendering.
class TransactionListItem extends StatelessWidget {
  const TransactionListItem.transaction(
    Transaction tx, {
    super.key,
    required VoidCallback onDetailsClosed,
  }) : _tx = tx,
       // ignore: prefer_initializing_formals
       _onDetailsClosed = onDetailsClosed;

  final Transaction _tx;

  /// Called when the details screen this row opened is closed, so the list
  /// can pick up anything edited there, labels in particular.
  final VoidCallback _onDetailsClosed;

  @override
  Widget build(BuildContext context) {
    return core.TxListItem(_transactionData(context, _tx));
  }

  core.TxListItemData _transactionData(
    BuildContext context,
    Transaction transaction,
  ) {
    final isLnSwap = transaction.isLnSwap;
    final isChainSwap = transaction.isChainSwap;
    final isOrderType = transaction.isOrder && transaction.order != null;
    final orderAmountAndCurrency = transaction.order
        ?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrderType && transaction.order!.displaysFiatAmount;
    final labels = transaction.walletTransaction != null
        ? transaction.walletTransaction!.labels
        : <Label>[];

    return core.TxListItemData(
      icon: isOrderType
          ? Icons.payments
          : isChainSwap
          ? Icons.swap_vert_rounded
          : isLnSwap
          ? (transaction.isOutgoing ? Icons.arrow_upward : Icons.arrow_downward)
          : transaction.isOutgoing
          ? Icons.arrow_upward
          : Icons.arrow_downward,
      iconBackgroundColor: transaction.isOngoingSwap
          ? context.appColors.border.withValues(alpha: 0.3)
          : context.appColors.surface,
      iconBorderColor: transaction.isOngoingSwap
          ? context.appColors.border.withValues(alpha: 0.5)
          : context.appColors.border,
      amountSat:
          isOrderType && !showOrderInFiat && orderAmountAndCurrency != null
          ? orderAmountAndCurrency.$1.toInt()
          : transaction.swapListAmountSat,
      fiatAmount:
          isOrderType && showOrderInFiat && orderAmountAndCurrency != null
          ? orderAmountAndCurrency.$1.toDouble()
          : null,
      fiatCurrency:
          isOrderType && showOrderInFiat && orderAmountAndCurrency != null
          ? orderAmountAndCurrency.$2
          : null,
      labels: labels.isEmpty ? const [] : [LabelsWidget(labels: labels)],
      networkLabel: isOrderType
          ? transaction.order!.orderTypeLabel
          : isLnSwap
          ? context.loc.transactionNetworkLightning
          : isChainSwap
          ? transaction.isLiquidToBitcoinSwap
                ? context.loc.transactionSwapLiquidToBitcoin
                : context.loc.transactionSwapBitcoinToLiquid
          : transaction.isBitcoin
          ? context.loc.transactionNetworkBitcoin
          : context.loc.transactionNetworkLiquid,
      networkColor: isOrderType
          ? context.appColors.border
          : transaction.isOngoingSwap
          ? context.appColors.border.withValues(alpha: 0.3)
          : transaction.isBitcoin
          ? context.appColors.onTertiary
          : context.appColors.tertiary,
      status: _TransactionStatus(tx: transaction),
      onTap: () => _openTransaction(context, transaction),
    );
  }

  Future<void> _openTransaction(BuildContext context, Transaction tx) async {
    if (tx.orderSwap != null) {
      await context.pushNamed(
        TransactionsRoute.orderSwapTransactionDetails.name,
        pathParameters: {'localId': tx.orderSwap!.localId},
      );
    } else if (tx.walletTransaction != null) {
      await context.pushNamed(
        TransactionsRoute.transactionDetails.name,
        pathParameters: {'txId': tx.walletTransaction!.txId},
        queryParameters: {'walletId': tx.walletTransaction!.walletId},
      );
    } else if (tx.swap != null) {
      await context.pushNamed(
        TransactionsRoute.swapTransactionDetails.name,
        pathParameters: {'swapId': tx.swap!.id},
        queryParameters: {'walletId': tx.swap!.walletId},
      );
    } else if (tx.payjoin != null) {
      await context.pushNamed(
        TransactionsRoute.payjoinTransactionDetails.name,
        pathParameters: {'payjoinId': tx.payjoin!.id},
      );
    } else if (tx.order != null) {
      await context.pushNamed(
        TransactionsRoute.orderTransactionDetails.name,
        pathParameters: {'orderId': tx.order!.orderId},
      );
    } else {
      return;
    }

    _onDetailsClosed();
  }
}

class _TransactionStatus extends StatelessWidget {
  const _TransactionStatus({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final isOrderType = tx.isOrder && tx.order != null;
    final date = tx.isSwap
        ? (!tx.isOngoingSwap
              ? (tx.swap?.completionTime != null ||
                        tx.orderSwap?.order?.completedAt != null
                    ? timeago.format(
                        tx.swap?.completionTime ??
                            tx.orderSwap!.order!.completedAt!,
                      )
                    : null)
              : null)
        : isOrderType
        ? (tx.order?.completedAt != null
              ? timeago.format(tx.order!.completedAt!)
              : null)
        : (tx.isBitcoin || tx.isLiquid)
        ? (tx.timestamp != null ? timeago.format(tx.timestamp!) : null)
        : null;

    if (isOrderType && tx.order!.isCompleted() && date != null) {
      return core.StatusRow(label: date, icon: Icons.check_circle);
    } else if (isOrderType) {
      return core.StatusRow(label: tx.order!.orderStatus.value);
    } else if (tx.isSwap &&
        (tx.swap?.completionTime != null ||
            tx.swap?.status == SwapStatus.completed ||
            tx.orderSwap?.localStatus == OrderSwapLocalStatus.completed ||
            tx.orderSwap?.localStatus == OrderSwapLocalStatus.refunded)) {
      return core.StatusRow(label: date ?? '', icon: Icons.check_circle);
    } else if (!tx.isSwap && (tx.walletTransaction?.isConfirmed ?? false)) {
      return core.StatusRow(label: date ?? '', icon: Icons.check_circle);
    } else if (date != null && isOrderType) {
      return core.StatusRow(label: date, icon: Icons.check_circle);
    } else if (date != null && tx.isOngoingSwap) {
      return core.StatusRow(
        label: date,
        icon: Icons.sync,
        iconColor: context.appColors.textMuted,
      );
    }

    return core.StatusRow(
      label: tx.isOngoingSwap
          ? context.loc.transactionStatusInProgress
          : context.loc.transactionStatusPending,
      icon: tx.isOngoingSwap ? Icons.sync : null,
      iconColor: context.appColors.textMuted,
    );
  }
}
