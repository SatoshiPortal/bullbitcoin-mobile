import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/transaction_details_page.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _directionLabel(BuildContext context, SpPaymentDirection direction) {
  switch (direction) {
    case SpPaymentDirection.receive:
      return context.loc.spReceived;
    case SpPaymentDirection.send:
      return context.loc.spSent;
    case SpPaymentDirection.selfSend:
      return context.loc.spSelfSend;
  }
}

class SpTransactionDetailsScreen extends StatelessWidget {
  const SpTransactionDetailsScreen({super.key, required this.payment});

  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final isIncoming = payment.direction == SpPaymentDirection.receive;

    return TransactionDetailsPage(
      title: context.loc.spTransactionTitle,
      isLoading: false,
      isIncoming: isIncoming,
      onClose: () => context.pop(),
      status: _SpDetailsStatusLabel(payment: payment),
      amount: Text(
        context.loc.spSendSatsAmount(
          FormatAmount.satsGrouped(payment.amountSat.toInt()),
        ),
        style: context.font.displaySmall?.copyWith(
          color: context.appColors.secondary,
          fontWeight: .w500,
        ),
      ),
      details: Column(
        children: [
          DetailsTable(
            items: [
              DetailsTableItem(
                label: context.loc.spDirectionLabel,
                displayValue: _directionLabel(context, payment.direction),
              ),
              DetailsTableItem(
                label: context.loc.amountLabel,
                displayValue: context.loc.spSendSatsAmount(
                  FormatAmount.satsGrouped(payment.amountSat.toInt()),
                ),
              ),
              if (payment.feeSat != null)
                DetailsTableItem(
                  label: context.loc.spFeeLabel,
                  displayValue: context.loc.spSendSatsAmount(
                    FormatAmount.satsGrouped(payment.feeSat!.toInt()),
                  ),
                ),
              if (payment.height != null)
                DetailsTableItem(
                  label: context.loc.spBlockRowLabel,
                  displayValue: '${payment.height}',
                ),
              if (payment.timestamp != null)
                DetailsTableItem(
                  label: context.loc.spTransactionDateLabel,
                  displayValue: DateFormat('MMM d, y, h:mm a').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      payment.timestamp!.toInt() * 1000,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.loc.spTransactionIdLabel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ),
          const Gap(4),
          Align(
            alignment: Alignment.centerLeft,
            child: AddressViewer(payment.txid),
          ),
        ],
      ),
    );
  }
}

class _SpDetailsStatusLabel extends StatelessWidget {
  const _SpDetailsStatusLabel({required this.payment});
  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final clickable =
        payment.status == SpPaymentStatus.confirmedUnverified ||
        payment.status == SpPaymentStatus.verifyFailed;
    final style = context.font.titleMedium?.copyWith(
      color: payment.status == SpPaymentStatus.verifyFailed
          ? context.appColors.error
          : null,
      decoration: clickable ? TextDecoration.underline : null,
    );
    final label = switch (payment.status) {
      SpPaymentStatus.unconfirmed => context.loc.spUnconfirmed,
      SpPaymentStatus.confirmedUnverified => context.loc.spVerifying,
      SpPaymentStatus.verified => context.loc.spConfirmed,
      SpPaymentStatus.verifyFailed => context.loc.spVerificationFailed,
    };
    if (!clickable) return Text(label, style: style);
    return InkWell(
      onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
      child: Text(label, style: style),
    );
  }
}
