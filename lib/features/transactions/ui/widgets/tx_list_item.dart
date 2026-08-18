import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class TxListItem extends StatelessWidget {
  const TxListItem({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final isLnSwap = tx.isLnSwap;
    final isChainSwap = tx.isChainSwap;
    final isOrderType = tx.isOrder && tx.order != null;
    final icon = isOrderType
        ? Icons.payments
        : isChainSwap
        ? Icons.swap_vert_rounded
        : isLnSwap
        ? (tx.isOutgoing ? Icons.arrow_upward : Icons.arrow_downward)
        : tx.isOutgoing
        ? Icons.arrow_upward
        : Icons.arrow_downward;
    final walletColor = isOrderType
        ? context.bull.border
        : tx.isOngoingSwap
        ? context.bull.border.withValues(alpha: 0.3)
        : tx.isBitcoin
        ? context.bull.onTertiary
        : context.bull.tertiary;
    final networkLabel = isOrderType
        ? tx.order!.orderTypeLabel
        : isLnSwap
        ? context.loc.transactionNetworkLightning
        : isChainSwap
        ? tx.isLiquidToBitcoinSwap
              ? context.loc.transactionSwapLiquidToBitcoin
              : context.loc.transactionSwapBitcoinToLiquid
        : tx.isBitcoin
        ? context.loc.transactionNetworkBitcoin
        : context.loc.transactionNetworkLiquid;
    final labels = tx.walletTransaction != null
        ? tx.walletTransaction!.labels
        : <Label>[];
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
    final orderAmountAndCurrency = tx.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat = isOrderType && tx.order!.displaysFiatAmount;
    return InkWell(
      onTap: () {
        if (tx.orderSwap != null) {
          context.pushNamed(
            TransactionsRoute.orderSwapTransactionDetails.name,
            pathParameters: {'localId': tx.orderSwap!.localId},
          );
          return;
        } else if (tx.walletTransaction != null) {
          context.pushNamed(
            TransactionsRoute.transactionDetails.name,
            pathParameters: {'txId': tx.walletTransaction!.txId},
            queryParameters: {'walletId': tx.walletTransaction!.walletId},
          );
          return;
        } else if (tx.swap != null) {
          context.pushNamed(
            TransactionsRoute.swapTransactionDetails.name,
            pathParameters: {'swapId': tx.swap!.id},
            queryParameters: {'walletId': tx.swap!.walletId},
          );
          return;
        } else if (tx.payjoin != null) {
          context.pushNamed(
            TransactionsRoute.payjoinTransactionDetails.name,
            pathParameters: {'payjoinId': tx.payjoin!.id},
          );
          return;
        } else if (tx.order != null) {
          context.pushNamed(
            TransactionsRoute.orderTransactionDetails.name,
            pathParameters: {'orderId': tx.order!.orderId},
          );
          return;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: context.bull.surface,
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: const [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: tx.isOngoingSwap
                    ? context.bull.border.withValues(alpha: 0.3)
                    : context.bull.surface,
                border: Border.all(
                  color: tx.isOngoingSwap
                      ? context.bull.border.withValues(alpha: 0.5)
                      : context.bull.border,
                ),
                borderRadius: BorderRadius.circular(2.0),
              ),
              child: BullIcon(icon, color: context.bull.onSurface),
            ),
            const Gap(16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  CurrencyText(
                    isOrderType &&
                            !showOrderInFiat &&
                            orderAmountAndCurrency != null
                        ? orderAmountAndCurrency.$1.toInt()
                        : tx.swapListAmountSat,
                    showFiat: false,
                    style: context.bullText.bodyLarge,
                    fiatAmount:
                        isOrderType &&
                            showOrderInFiat &&
                            orderAmountAndCurrency != null
                        ? orderAmountAndCurrency.$1.toDouble()
                        : null,
                    fiatCurrency:
                        isOrderType &&
                            showOrderInFiat &&
                            orderAmountAndCurrency != null
                        ? orderAmountAndCurrency.$2
                        : null,
                  ),

                  if (labels.isNotEmpty && tx.walletTransaction != null)
                    LabelsWidget(labels: labels),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: .end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: walletColor,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                  child: BullText(
                    networkLabel,
                    style: context.bullText.labelSmall?.copyWith(
                      color: context.bull.onSurface,
                    ),
                  ),
                ),
                const Gap(4.0),
                if (isOrderType && tx.order!.isCompleted() && date != null)
                  Row(
                    children: [
                      BullText(
                        date,
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.check_circle,
                        size: 12.0,
                        color: context.bull.success,
                      ),
                    ],
                  )
                else if (isOrderType)
                  Row(
                    children: [
                      BullText(
                        tx.order!.orderStatus.value,
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                    ],
                  )
                else if (tx.isSwap &&
                    (tx.swap?.completionTime != null ||
                        tx.swap?.status == SwapStatus.completed ||
                        tx.orderSwap?.localStatus ==
                            OrderSwapLocalStatus.completed ||
                        tx.orderSwap?.localStatus ==
                            OrderSwapLocalStatus.refunded))
                  Row(
                    children: [
                      BullText(
                        date ?? '',
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.check_circle,
                        size: 12.0,
                        color: context.bull.success,
                      ),
                    ],
                  )
                else if (!tx.isSwap &&
                    (tx.walletTransaction?.isConfirmed ?? false))
                  Row(
                    children: [
                      BullText(
                        date ?? '',
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.check_circle,
                        size: 12.0,
                        color: context.bull.success,
                      ),
                    ],
                  )
                else if (date != null && isOrderType)
                  Row(
                    children: [
                      BullText(
                        date,
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.check_circle,
                        size: 12.0,
                        color: context.bull.success,
                      ),
                    ],
                  )
                else if (date != null && tx.isOngoingSwap)
                  Row(
                    children: [
                      BullText(
                        date,
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.sync,
                        size: 12.0,
                        color: context.bull.textMuted,
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      BullText(
                        tx.isOngoingSwap
                            ? context.loc.transactionStatusInProgress
                            : context.loc.transactionStatusPending,
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(4.0),
                      if (tx.isOngoingSwap)
                        Icon(
                          Icons.sync,
                          size: 12.0,
                          color: context.bull.textMuted,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
