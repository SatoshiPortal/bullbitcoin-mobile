import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class TxListItem extends StatelessWidget {
  const TxListItem.transaction(Transaction tx, {super.key})
    : _tx = tx,
      _spPayment = null;

  const TxListItem.sp(SpPayment payment, {super.key})
    : _tx = null,
      _spPayment = payment;

  final Transaction? _tx;
  final SpPayment? _spPayment;

  @override
  Widget build(BuildContext context) {
    final data = _tx != null
        ? _transactionData(context, _tx)
        : _spPaymentData(context, _spPayment);

    return InkWell(
      onTap: data.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: const [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: data.iconBackgroundColor,
                border: Border.all(color: data.iconBorderColor),
                borderRadius: BorderRadius.circular(2.0),
              ),
              child: Icon(data.icon, color: context.appColors.onSurface),
            ),
            const Gap(16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  CurrencyText(
                    data.amountSat,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    fiatAmount: data.fiatAmount,
                    fiatCurrency: data.fiatCurrency,
                  ),
                  if (data.labels.isNotEmpty) LabelsWidget(labels: data.labels),
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
                    color: data.networkColor,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                  child: BBText(
                    data.networkLabel,
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                  ),
                ),
                const Gap(4.0),
                data.status,
              ],
            ),
          ],
        ),
      ),
    );
  }

  _TxListItemData _transactionData(BuildContext context, Transaction? tx) {
    final transaction = tx!;
    final isLnSwap = transaction.isLnSwap;
    final isChainSwap = transaction.isChainSwap;
    final isOrderType = transaction.isOrder && transaction.order != null;
    final orderAmountAndCurrency = transaction.order
        ?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrderType &&
        (transaction.order is FiatPaymentOrder ||
            transaction.order is BalanceAdjustmentOrder ||
            transaction.order is WithdrawOrder ||
            transaction.order is FundingOrder);
    final labels = transaction.walletTransaction != null
        ? transaction.walletTransaction!.labels
        : <Label>[];

    return _TxListItemData(
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
      labels: labels,
      networkLabel: isOrderType
          ? transaction.order!.orderType.value
          : isLnSwap
          ? context.loc.transactionNetworkLightning
          : isChainSwap
          ? transaction.swap!.type == SwapType.liquidToBitcoin
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

  _TxListItemData _spPaymentData(BuildContext context, SpPayment? payment) {
    final spPayment = payment!;
    final isIncoming = spPayment.direction == SpPaymentDirection.receive;
    final isSp = spPayment.hasSpOutput;

    return _TxListItemData(
      icon: isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
      iconBackgroundColor: context.appColors.surface,
      iconBorderColor: context.appColors.border,
      amountSat: spPayment.amountSat.toInt(),
      labels: const [],
      networkLabel: isSp
          ? context.loc.spCoinSourceSp
          : context.loc.spReceiveTabTaproot.toUpperCase(),
      networkColor: isSp
          ? context.appColors.success
          : context.appColors.tertiary,
      status: _SpPaymentStatus(payment: spPayment),
      onTap: () => context.pushNamed(
        SpRoute.spTransactionDetails.name,
        extra: spPayment,
      ),
    );
  }

  void _openTransaction(BuildContext context, Transaction tx) {
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
  }
}

class _TxListItemData {
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconBorderColor;
  final int amountSat;
  final double? fiatAmount;
  final String? fiatCurrency;
  final List<Label> labels;
  final String networkLabel;
  final Color networkColor;
  final Widget status;
  final VoidCallback onTap;

  const _TxListItemData({
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconBorderColor,
    required this.amountSat,
    this.fiatAmount,
    this.fiatCurrency,
    required this.labels,
    required this.networkLabel,
    required this.networkColor,
    required this.status,
    required this.onTap,
  });
}

class _TransactionStatus extends StatelessWidget {
  const _TransactionStatus({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final isOrderType = tx.isOrder && tx.order != null;
    final date = tx.isSwap
        ? (!tx.isOngoingSwap
              ? (tx.swap?.completionTime != null
                    ? timeago.format(tx.swap!.completionTime!)
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
      return _StatusRow(label: date, icon: Icons.check_circle);
    } else if (isOrderType) {
      return _StatusRow(label: tx.order!.orderStatus.value);
    } else if (tx.isSwap &&
        (tx.swap?.completionTime != null ||
            tx.swap?.status == SwapStatus.completed)) {
      return _StatusRow(label: date ?? '', icon: Icons.check_circle);
    } else if (!tx.isSwap && (tx.walletTransaction?.isConfirmed ?? false)) {
      return _StatusRow(label: date ?? '', icon: Icons.check_circle);
    } else if (date != null && isOrderType) {
      return _StatusRow(label: date, icon: Icons.check_circle);
    } else if (date != null && tx.isOngoingSwap) {
      return _StatusRow(
        label: date,
        icon: Icons.sync,
        iconColor: context.appColors.textMuted,
      );
    }

    return _StatusRow(
      label: tx.isOngoingSwap
          ? context.loc.transactionStatusInProgress
          : context.loc.transactionStatusPending,
      icon: tx.isOngoingSwap ? Icons.sync : null,
      iconColor: context.appColors.textMuted,
    );
  }
}

class _SpPaymentStatus extends StatelessWidget {
  const _SpPaymentStatus({required this.payment});

  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final clickable =
        payment.status == SpPaymentStatus.confirmedUnverified ||
        payment.status == SpPaymentStatus.verifyFailed;
    final date = payment.timestamp != null
        ? timeago.format(
            DateTime.fromMillisecondsSinceEpoch(
              payment.timestamp!.toInt() * 1000,
            ),
          )
        : null;
    final label = switch (payment.status) {
      SpPaymentStatus.unconfirmed => context.loc.transactionStatusPending,
      SpPaymentStatus.confirmedUnverified =>
        date != null
            ? '$date (${context.loc.spVerifying})'
            : context.loc.spVerifying,
      SpPaymentStatus.verified => date ?? context.loc.spConfirmed,
      SpPaymentStatus.verifyFailed => context.loc.spVerificationFailed,
    };
    final status = _StatusRow(
      label: label,
      icon: payment.status == SpPaymentStatus.verified && date != null
          ? Icons.check_circle
          : null,
      textColor: payment.status == SpPaymentStatus.verifyFailed
          ? context.appColors.error
          : context.appColors.textMuted,
      decoration: clickable ? TextDecoration.underline : null,
    );
    if (!clickable) return status;

    return InkWell(
      onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
      child: status,
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.decoration,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final TextDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BBText(
          label,
          style: context.font.labelSmall?.copyWith(
            color: textColor ?? context.appColors.textMuted,
            decoration: decoration,
          ),
        ),
        if (icon != null) ...[
          const Gap(4.0),
          Icon(icon, size: 12.0, color: iconColor ?? context.appColors.success),
        ],
      ],
    );
  }
}
