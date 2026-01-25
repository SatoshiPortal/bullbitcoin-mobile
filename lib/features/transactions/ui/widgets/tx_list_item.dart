import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/labels_widget.dart';
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

  String _getLabel(BuildContext context) {
    if (tx.isOrder && tx.order != null) {
      return tx.order!.orderType.value;
    }
    if (tx.isChainSwap) {
      return tx.swap!.type == SwapType.liquidToBitcoin
          ? context.loc.transactionSwapLiquidToBitcoin
          : context.loc.transactionSwapBitcoinToLiquid;
    }
    if (tx.isLnSwap) {
      return tx.isOutgoing
          ? context.loc.transactionFilterSend
          : context.loc.transactionFilterReceive;
    }
    return tx.isOutgoing
        ? context.loc.transactionFilterSend
        : context.loc.transactionFilterReceive;
  }

  String _getNetworkTag(BuildContext context) {
    if (tx.isOrder && tx.order != null) {
      return 'Exchange';
    }
    if (tx.isLnSwap) {
      return context.loc.transactionNetworkLightning;
    }
    if (tx.isChainSwap) {
      return tx.swap!.type == SwapType.liquidToBitcoin
          ? context.loc.transactionSwapLiquidToBitcoin
          : context.loc.transactionSwapBitcoinToLiquid;
    }
    if (tx.isBitcoin) {
      return context.loc.transactionNetworkBitcoin;
    }
    return context.loc.transactionNetworkLiquid;
  }

  Color _getNetworkTagColor(BuildContext context) {
    if (tx.isOrder || tx.isOngoingSwap) {
      return context.appColors.border;
    }
    if (tx.isBitcoin) {
      return context.appColors.onTertiary;
    }
    return context.appColors.tertiary;
  }

  Color _getNetworkTagTextColor(BuildContext context) {
    if (tx.isOrder) {
      return context.appColors.secondary;
    }
    if (tx.isBitcoin) {
      return context.appColors.onTertiary;
    }
    return context.appColors.tertiary;
  }

  String? _getDate() {
    if (tx.isSwap) {
      if (!tx.isOngoingSwap && tx.swap?.completionTime != null) {
        return timeago.format(tx.swap!.completionTime!);
      }
      return null;
    }
    if (tx.isOrder && tx.order != null) {
      if (tx.order!.completedAt != null) {
        return timeago.format(tx.order!.completedAt!);
      }
      return null;
    }
    if (tx.timestamp != null) {
      return timeago.format(tx.timestamp!);
    }
    return null;
  }

  bool _isPending() {
    if (tx.isOngoingSwap) return true;
    if (tx.isOrder && tx.order != null && !tx.order!.isCompleted()) return true;
    if (tx.walletTransaction != null && !tx.walletTransaction!.isConfirmed) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isReceive = tx.isIncoming;
    final isPending = _isPending();
    final date = _getDate();
    final label = _getLabel(context);
    final txLabels =
        tx.walletTransaction != null ? tx.walletTransaction!.labels : <String>[];

    final isOrderType = tx.isOrder && tx.order != null;
    final orderAmountAndCurrency = tx.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat = isOrderType &&
        (tx.order is FiatPaymentOrder ||
            tx.order is BalanceAdjustmentOrder ||
            tx.order is WithdrawOrder ||
            tx.order is FundingOrder);

    final amountSat = isOrderType &&
            !showOrderInFiat &&
            orderAmountAndCurrency != null
        ? orderAmountAndCurrency.$1.toInt()
        : tx.isSwap && tx.swap != null
            ? tx.swap!.amountSat
            : tx.amountSat;

    final iconColor =
        isReceive ? context.appColors.secondary : context.appColors.textMuted;

    return InkWell(
      onTap: () => _navigateToDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isReceive ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: iconColor,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      BBText(
                        label,
                        style: context.font.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        color: context.appColors.text,
                      ),
                      if (isPending) ...[
                        const Gap(6),
                        Text(
                          '•',
                          style: TextStyle(
                            color:
                                context.appColors.textMuted.withValues(alpha: 0.5),
                            fontSize: 8,
                          ),
                        ),
                        const Gap(6),
                        BBText(
                          tx.isOngoingSwap
                              ? context.loc.transactionStatusInProgress
                              : context.loc.transactionStatusPending,
                          style: context.font.labelSmall?.copyWith(fontSize: 10),
                          color: context.appColors.warning,
                        ),
                      ],
                    ],
                  ),
                  if (date != null)
                    BBText(
                      date,
                      style: context.font.labelSmall?.copyWith(fontSize: 10),
                      color: context.appColors.textMuted.withValues(alpha: 0.6),
                    )
                  else if (isPending)
                    BBText(
                      context.loc.transactionStatusPending,
                      style: context.font.labelSmall?.copyWith(fontSize: 10),
                      color: context.appColors.textMuted.withValues(alpha: 0.6),
                    ),
                  if (txLabels.isNotEmpty && tx.walletTransaction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: txLabels.map((lbl) => LabelChip(
                          label: lbl,
                          onDelete: null,
                          compact: true,
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _getNetworkTagColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _getNetworkTag(context),
                    style: context.font.labelSmall?.copyWith(
                      fontSize: 9,
                      color: _getNetworkTagTextColor(context),
                    ),
                  ),
                ),
                const Gap(2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isReceive ? '+' : '-',
                      style: context.font.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: iconColor,
                      ),
                    ),
                    CurrencyText(
                      amountSat,
                      showFiat: false,
                      style: context.font.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      color: iconColor,
                      fiatAmount: isOrderType &&
                              showOrderInFiat &&
                              orderAmountAndCurrency != null
                          ? orderAmountAndCurrency.$1.toDouble()
                          : null,
                      fiatCurrency: isOrderType &&
                              showOrderInFiat &&
                              orderAmountAndCurrency != null
                          ? orderAmountAndCurrency.$2
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    if (tx.walletTransaction != null) {
      context.pushNamed(
        TransactionsRoute.transactionDetails.name,
        pathParameters: {'txId': tx.walletTransaction!.txId},
        queryParameters: {'walletId': tx.walletTransaction!.walletId},
      );
    } else if (tx.swap != null) {
      context.pushNamed(
        TransactionsRoute.swapTransactionDetails.name,
        pathParameters: {'swapId': tx.swap!.id},
        queryParameters: {'walletId': tx.swap!.walletId},
      );
    } else if (tx.payjoin != null) {
      context.pushNamed(
        TransactionsRoute.payjoinTransactionDetails.name,
        pathParameters: {'payjoinId': tx.payjoin!.id},
      );
    } else if (tx.order != null) {
      context.pushNamed(
        TransactionsRoute.orderTransactionDetails.name,
        pathParameters: {'orderId': tx.order!.orderId},
      );
    }
  }
}
