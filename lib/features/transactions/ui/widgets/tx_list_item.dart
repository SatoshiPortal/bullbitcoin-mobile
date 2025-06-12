import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
            : tx.isOutgoing
            ? Icons.arrow_upward
            : Icons.arrow_downward;
    final walletColor =
        isOrderType
            ? context.colour.secondaryFixedDim
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
                ? 'L-BTC -> BTC'
                : 'BTC -> L-BTC'
            : tx.isBitcoin
            ? 'Bitcoin'
            : 'Liquid';
    final label =
        tx.walletTransaction != null && tx.walletTransaction!.labels.isNotEmpty
            ? tx.walletTransaction!.labels.first
            : null;
    final date =
        tx.timestamp != null
            ? timeago.format(tx.timestamp!)
            : isOrderType && tx.order!.completedAt != null
            ? timeago.format(tx.order!.createdAt)
            : null;
    final orderAmountAndCurrency = tx.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrderType &&
        (tx.order is FiatPaymentOrder ||
            tx.order is BalanceAdjustmentOrder ||
            tx.order is WithdrawOrder);
    return InkWell(
      onTap: () {
        context.pushNamed(TransactionsRoute.transactionDetails.name, extra: tx);
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
                color: context.colour.onPrimary,
                border: Border.all(color: context.colour.surface),
                borderRadius: BorderRadius.circular(2.0),
              ),
              child: Icon(icon, color: context.colour.secondary),
            ),
            const Gap(16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CurrencyText(
                        isOrderType && !showOrderInFiat
                            ? orderAmountAndCurrency!.$1.toInt()
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
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: BBText(
                              label,
                              style: context.font.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
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
                if (date != null)
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
                else ...[
                  BBText(
                    'Pending',
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
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
