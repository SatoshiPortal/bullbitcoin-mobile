import 'package:swaps/swaps.dart';
import 'package:transactions/src/ui/widgets/exchange_order_fiat_amount.dart';
import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:labels/labels.dart';
import 'package:label_editor/label_editor.dart';
import 'package:swaps/order_swaps.dart';
import 'package:transactions/src/domain/entities/transaction.dart';
import 'package:transactions/src/presentation/order_l10n.dart';

import '../transactions_navigation.dart';

import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullTransactionListItem,
        BullTransactionListItemData,
        BullTransactionStatusRow,
        bullTimeAgo,
        BullTypographyX;

/// Feature-side entry point of the shared row: maps a [Transaction] to a
/// [BullTransactionListItemData] and delegates the rendering.
class TransactionListItem extends StatelessWidget {
  const TransactionListItem.transaction(
    Transaction tx, {
    super.key,
    required VoidCallback onDetailsClosed,
    this.walletScoped = false,
  }) : _tx = tx,
       // ignore: prefer_initializing_formals
       _onDetailsClosed = onDetailsClosed;

  final Transaction _tx;

  /// The row is in one wallet's list: a swap shows that wallet's own side,
  /// its direction and exactly what it sent or received.
  final bool walletScoped;

  /// Called when the details screen this row opened is closed, so the list
  /// can pick up anything edited there, labels in particular.
  final VoidCallback _onDetailsClosed;

  @override
  Widget build(BuildContext context) {
    return BullTransactionListItem(
      _transactionData(context, _tx),
      key: ValueKey((
        _tx.walletTransaction?.walletId,
        _tx.walletTransaction?.txId,
        _tx.swap?.id,
        _tx.orderSwap?.localId,
        _tx.payjoin?.id,
        _tx.order?.orderId,
      )),
    );
  }

  BullTransactionListItemData _transactionData(
    BuildContext context,
    Transaction transaction,
  ) {
    final isLnSwap = transaction.isLnSwap;
    final isChainSwap = transaction.isChainSwap;
    final walletLeg =
        walletScoped &&
        transaction.isSwap &&
        transaction.walletTransaction != null;
    final isOrderType = transaction.isOrder && transaction.order != null;
    final orderAmountAndCurrency = transaction.order
        ?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrderType && transaction.order!.displaysFiatAmount;
    final labels = transaction.walletTransaction != null
        ? transaction.walletTransaction!.labels
        : <Label>[];

    return BullTransactionListItemData(
      icon: isOrderType
          ? Icons.payments
          : walletLeg
          ? (transaction.isOutgoing ? Icons.arrow_upward : Icons.arrow_downward)
          : isChainSwap
          ? Icons.swap_vert_rounded
          : isLnSwap
          ? (transaction.isOutgoing ? Icons.arrow_upward : Icons.arrow_downward)
          : transaction.isOutgoing
          ? Icons.arrow_upward
          : Icons.arrow_downward,
      iconBackgroundColor: transaction.isOngoingSwap
          ? context.bull.border.withValues(alpha: 0.3)
          : context.bull.surface,
      iconBorderColor: transaction.isOngoingSwap
          ? context.bull.border.withValues(alpha: 0.5)
          : context.bull.border,
      amount: showOrderInFiat && orderAmountAndCurrency != null
          ? ExchangeOrderFiatAmount(
              amount: orderAmountAndCurrency.$1.toDouble(),
              currency: orderAmountAndCurrency.$2,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            )
          : BullAmount.signedSats(
              isOrderType && orderAmountAndCurrency != null
                  ? orderAmountAndCurrency.$1.toInt()
                  : walletLeg
                  ? transaction.walletListAmountSat
                  : transaction.swapListAmountSat,
              interactive: true,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
      labels: labels.isEmpty
          ? const []
          : [LabelsWidget(labels: labels, maxCharacters: 12)],
      networkLabel: isOrderType
          ? transaction.order!.typeLabel(context)
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
          ? context.bull.border
          : transaction.isOngoingSwap
          ? context.bull.border.withValues(alpha: 0.3)
          : transaction.isBitcoin
          ? context.bull.onTertiary
          : context.bull.tertiary,
      status: _TransactionStatus(tx: transaction),
      onTap: () => _openTransaction(context, transaction),
    );
  }

  Future<void> _openTransaction(BuildContext context, Transaction tx) async {
    final target = switch (tx) {
      Transaction(orderSwap: final swap?) => TransactionDetailsTarget.orderSwap(
        swap.localId,
      ),
      Transaction(walletTransaction: final walletTx?) =>
        TransactionDetailsTarget.wallet(
          walletTx.txId,
          walletId: walletTx.walletId,
        ),
      Transaction(swap: final swap?) => TransactionDetailsTarget.swap(
        swap.id,
        walletId: swap.walletId,
      ),
      Transaction(payjoin: final payjoin?) => TransactionDetailsTarget.payjoin(
        payjoin.id,
      ),
      Transaction(order: final order?) => TransactionDetailsTarget.order(
        order.orderId,
      ),
      _ => null,
    };
    if (target == null) return;

    await TransactionsNavigation.openDetails(
      context,
      target,
      view: TransactionDetailsView.details,
    );
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
                    ? bullTimeAgo(
                        context,
                        tx.swap?.completionTime ??
                            tx.orderSwap!.order!.completedAt!,
                      )
                    : null)
              : null)
        : isOrderType
        ? (tx.order?.completedAt != null
              ? bullTimeAgo(context, tx.order!.completedAt!)
              : null)
        : (tx.isBitcoin || tx.isLiquid)
        ? (tx.timestamp != null ? bullTimeAgo(context, tx.timestamp!) : null)
        : null;

    if (isOrderType && tx.order!.isCompleted() && date != null) {
      return BullTransactionStatusRow(label: date, icon: Icons.check_circle);
    } else if (isOrderType) {
      return BullTransactionStatusRow(
        label: tx.order!.orderStatus.toTranslated(context),
      );
    } else if (tx.isSwap &&
        (tx.swap?.completionTime != null ||
            tx.swap?.status == SwapStatus.completed ||
            tx.orderSwap?.localStatus == OrderSwapLocalStatus.completed ||
            tx.orderSwap?.localStatus == OrderSwapLocalStatus.refunded)) {
      return BullTransactionStatusRow(
        label: date ?? '',
        icon: Icons.check_circle,
      );
    } else if (!tx.isSwap && (tx.walletTransaction?.isConfirmed ?? false)) {
      return BullTransactionStatusRow(
        label: date ?? '',
        icon: Icons.check_circle,
      );
    } else if (date != null && isOrderType) {
      return BullTransactionStatusRow(label: date, icon: Icons.check_circle);
    } else if (date != null && tx.isOngoingSwap) {
      return BullTransactionStatusRow(
        label: date,
        icon: Icons.sync,
        iconColor: context.bull.textMuted,
      );
    }

    return BullTransactionStatusRow(
      label: tx.isOngoingSwap
          ? context.loc.transactionStatusInProgress
          : context.loc.transactionStatusPending,
      icon: tx.isOngoingSwap ? Icons.sync : null,
      iconColor: context.bull.textMuted,
    );
  }
}
