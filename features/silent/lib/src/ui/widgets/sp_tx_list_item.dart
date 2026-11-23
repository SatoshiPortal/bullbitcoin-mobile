import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullThemeX,
        BullTransactionListItemData,
        BullTransactionStatusRow,
        BullTypographyX,
        bullTimeAgo;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:silent/src/ui/sp_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// Resolves an [SpPayment] into display data for the shared transaction row.
BullTransactionListItemData spPaymentListItemData(
  BuildContext context,
  SpPayment payment,
) {
  final isIncoming = payment.direction == SpPaymentDirection.receive;
  final isSp = payment.hasSpOutput;

  return BullTransactionListItemData(
    icon: isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
    iconBackgroundColor: context.bull.surface,
    iconBorderColor: context.bull.border,
    amount: BullAmount.signedSats(
      payment.amountSat.value.toInt(),
      interactive: true,
      style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
    ),
    labels: const [],
    networkLabel: isSp
        ? context.silentLoc.silentCoinSourceSp
        : context.silentLoc.silentReceiveTabTaproot.toUpperCase(),
    networkColor: isSp ? context.bull.success : context.bull.tertiary,
    status: SpPaymentStatusLabel(payment: payment),
    onTap: () =>
        context.pushNamed(SpRoute.spTransactionDetails.name, extra: payment),
  );
}

/// Status line for one Silent Payments history entry. Tapping an unverified or
/// failed entry opens the header validation screen that explains why.
class SpPaymentStatusLabel extends StatelessWidget {
  const SpPaymentStatusLabel({required this.payment, super.key});

  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final clickable =
        payment.status == SpPaymentStatus.confirmedUnverified ||
        payment.status == SpPaymentStatus.verifyFailed;
    final date = payment.timestamp != null
        ? bullTimeAgo(
            context,
            DateTime.fromMillisecondsSinceEpoch(
              payment.timestamp!.toInt() * 1000,
            ),
          )
        : null;
    final label = switch (payment.status) {
      SpPaymentStatus.unconfirmed => context.silentLoc.transactionStatusPending,
      SpPaymentStatus.confirmedUnverified =>
        date != null
            ? '$date (${context.silentLoc.silentVerifying})'
            : context.silentLoc.silentVerifying,
      SpPaymentStatus.verified => date ?? context.silentLoc.silentConfirmed,
      SpPaymentStatus.verifyFailed =>
        context.silentLoc.silentVerificationFailed,
    };
    final status = BullTransactionStatusRow(
      label: label,
      icon: payment.status == SpPaymentStatus.verified && date != null
          ? Icons.check_circle
          : null,
      textColor: payment.status == SpPaymentStatus.verifyFailed
          ? context.bull.error
          : context.bull.textMuted,
      decoration: clickable ? TextDecoration.underline : null,
    );
    if (!clickable) return status;

    return InkWell(
      onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
      child: status,
    );
  }
}
