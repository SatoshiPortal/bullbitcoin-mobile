import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_history_screen.dart';
import 'package:bb_mobile/features/invoices/public/invoices_routes.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GetPaidTransactionDetailScreen extends StatelessWidget {
  final GetPaidTransaction transaction;

  const GetPaidTransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return BullScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.getPaidTransactionDetailTitle,
              onBack: context.pop,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    getPaidTransactionAmountText(
                      context,
                      transaction.amountSat,
                    ),
                    textAlign: TextAlign.center,
                    style: context.bullText.headlineLarge,
                  ),
                  const Gap(24),
                  _DetailRow(
                    label: context.loc.getPaidTransactionsSourceLabel,
                    value: getPaidTransactionSourceText(
                      context,
                      transaction.source,
                    ),
                  ),
                  const Divider(),
                  _DetailRow(
                    label: context.loc.getPaidTransactionsReceivedLabel,
                    value: getPaidTransactionDateText(
                      context,
                      transaction.receivedAt,
                    ),
                  ),
                  const Divider(),
                  _DetailRow(
                    label: context.loc.getPaidTransactionsRailLabel,
                    value: getPaidTransactionRailText(
                      context,
                      transaction.rail,
                    ),
                  ),
                  const Divider(),
                  _DetailRow(
                    label: context.loc.getPaidTransactionsStatusLabel,
                    value: getPaidSettlementStateText(
                      context,
                      transaction.settlementState,
                    ),
                  ),
                  if (transaction.late) ...[
                    const Divider(),
                    _DetailRow(
                      label: context.loc.getPaidTransactionsTimingLabel,
                      value: context.loc.getPaidTransactionsLate,
                      valueColor: colors.warning,
                    ),
                  ],
                  if (transaction.comment case final comment?) ...[
                    const Gap(24),
                    Text(
                      context.loc.getPaidTransactionsCommentLabel,
                      style: context.bullText.labelMedium?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      comment,
                      key: const ValueKey('get-paid-transaction-comment'),
                      style: context.bullText.bodyLarge,
                    ),
                  ],
                  if (transaction.invoiceId case final invoiceId?) ...[
                    const Gap(32),
                    BullButton.big(
                      label: context.loc.getPaidTransactionsViewInvoice,
                      iconData: Icons.receipt_long,
                      iconFirst: true,
                      onPressed: () => context.pushNamed(
                        InvoicesRoute.detail.name,
                        pathParameters: {'id': invoiceId},
                      ),
                      bgColor: colors.primary,
                      textColor: colors.onPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.bullText.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
          const Gap(16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.bullText.bodyLarge?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
