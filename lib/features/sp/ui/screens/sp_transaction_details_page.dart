import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
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

class SpTransactionDetailsPage extends StatelessWidget {
  const SpTransactionDetailsPage({super.key, required this.payment});

  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final isIncoming = payment.direction == SpPaymentDirection.receive;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.spTransactionTitle, style: context.font.headlineMedium),
        leading: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(
                  isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 48,
                  color:
                      isIncoming
                          ? context.appColors.success
                          : context.appColors.error,
                ),
                const Gap(24),
                Text(
                  payment.height != null
                      ? context.loc.spConfirmed
                      : context.loc.spUnconfirmed,
                  style: context.font.titleMedium,
                ),
                const Gap(8),
                Text(
                  context.loc.spSendSatsAmount(
                    FormatAmount.satsGrouped(payment.amountSat.toInt()),
                  ),
                  style: context.font.displaySmall?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
                const Gap(24),
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
          ),
        ),
      ),
    );
  }
}

