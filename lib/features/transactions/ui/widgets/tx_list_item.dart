import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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
    final icon =
        isOrderType
            ? Icons.payments
            : isChainSwap
            ? Icons.swap_vert_rounded
            : isLnSwap
            ? Icons.flash_on
            : tx.isOutgoing
            ? Icons.arrow_upward
            : Icons.arrow_downward;
    final walletColor =
        isOrderType
            ? context.colour.secondaryFixedDim
            : tx.isOngoingSwap
            ? context.colour.secondaryContainer.withValues(alpha: 0.3)
            : tx.isBitcoin
            ? context.colour.onTertiary
            : context.colour.tertiary;
    final networkLabel =
        isOrderType
            ? tx.order!.orderType.value
            : isLnSwap
            ? 'Lightning'
            : isChainSwap
            ? tx.swap!.type == SwapType.liquidToBitcoin
                ? 'L-BTC → BTC'
                : 'BTC → L-BTC'
            : tx.isBitcoin
            ? 'Bitcoin'
            : 'Liquid';
    final label =
        tx.walletTransaction != null && tx.walletTransaction!.labels.isNotEmpty
            ? tx.walletTransaction!.labels.first
            : null;
    final date =
        tx.isSwap
            ? (tx.swap?.completionTime != null
                ? timeago.format(tx.swap!.completionTime!)
                : null)
            : isOrderType
            ? (tx.order?.completedAt != null
                ? timeago.format(tx.order!.completedAt!)
                : null)
            : (tx.isBitcoin || tx.isLiquid)
            ? (tx.timestamp != null ? timeago.format(tx.timestamp!) : null)
            : null;
    final orderAmountAndCurrency = tx.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrderType &&
        (tx.order is FiatPaymentOrder ||
            tx.order is BalanceAdjustmentOrder ||
            tx.order is WithdrawOrder ||
            tx.order is FundingOrder);
    return InkWell(
      onTap: () {
        if (tx.walletTransaction != null) {
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
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: const [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color:
                    tx.isOngoingSwap
                        ? context.colour.secondaryContainer.withValues(
                          alpha: 0.3,
                        )
                        : context.colour.onPrimary,
                border: Border.all(
                  color:
                      tx.isOngoingSwap
                          ? context.colour.secondary.withValues(alpha: 0.5)
                          : context.colour.surface,
                ),
                borderRadius: BorderRadius.circular(2.0),
              ),
              child: Icon(
                icon,
                color:
                    tx.isOngoingSwap
                        ? context.colour.secondary
                        : context.colour.secondary,
              ),
            ),
            const Gap(16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CurrencyText(
                    isOrderType && !showOrderInFiat
                        ? orderAmountAndCurrency!.$1.toInt()
                        : tx.isSwap
                        ? (tx.swap!.amountSat -
                            tx.swap!.fees!.totalFees(tx.swap!.amountSat))
                        : tx.amountSat,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    fiatAmount:
                        isOrderType && showOrderInFiat
                            ? orderAmountAndCurrency!.$1.toDouble()
                            : null,
                    fiatCurrency:
                        isOrderType && showOrderInFiat
                            ? orderAmountAndCurrency!.$2
                            : null,
                  ),

                  if (label != null)
                    BBText(
                      label,
                      style: context.font.labelSmall?.copyWith(
                        color: context.colour.outline,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                  child: BBText(
                    networkLabel,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
                const Gap(4.0),
                if (isOrderType && tx.order!.isCompleted() && date != null)
                  Row(
                    children: [
                      BBText(
                        date,
                        style: context.font.labelSmall?.copyWith(
                          color: context.colour.outline,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.check_circle,
                        size: 12.0,
                        color: context.colour.inverseSurface,
                      ),
                    ],
                  )
                else if (isOrderType)
                  Row(
                    children: [
                      BBText(
                        tx.order!.orderStatus.value,
                        style: context.font.labelSmall?.copyWith(
                          color: context.colour.outline,
                        ),
                      ),
                    ],
                  )
                else if (date != null)
                  Row(
                    children: [
                      BBText(
                        date,
                        style: context.font.labelSmall?.copyWith(
                          color:
                              tx.isOngoingSwap
                                  ? context.colour.secondary
                                  : context.colour.outline,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        tx.isOngoingSwap ? Icons.sync : Icons.check_circle,
                        size: 12.0,
                        color:
                            tx.isOngoingSwap
                                ? context.colour.secondary
                                : context.colour.inverseSurface,
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      BBText(
                        tx.isOngoingSwap ? 'In Progress' : 'Pending',
                        style: context.font.labelSmall?.copyWith(
                          color:
                              tx.isOngoingSwap
                                  ? context.colour.secondary
                                  : context.colour.outline,
                        ),
                      ),
                      const Gap(4.0),
                      if (tx.isOngoingSwap)
                        Icon(
                          Icons.sync,
                          size: 12.0,
                          color: context.colour.secondary,
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
