import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/tx_list_item.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Resolves an [SpPayment] into the shared [TxListItemData] the core row
/// renders.
///
/// Lives in SP rather than in the row itself so `tx_list_item.dart` never has
/// to import SP types.
TxListItemData spPaymentListItemData(BuildContext context, SpPayment payment) {
  final isIncoming = payment.direction == SpPaymentDirection.receive;
  final isSp = payment.hasSpOutput;

  return TxListItemData(
    icon: isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
    iconBackgroundColor: context.appColors.surface,
    iconBorderColor: context.appColors.border,
    amountSat: payment.amountSat.value.toInt(),
    labels: const [],
    networkLabel: isSp
        ? context.loc.spCoinSourceSp
        : context.loc.spReceiveTabTaproot.toUpperCase(),
    networkColor: isSp ? context.appColors.success : context.appColors.tertiary,
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
    final status = StatusRow(
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
