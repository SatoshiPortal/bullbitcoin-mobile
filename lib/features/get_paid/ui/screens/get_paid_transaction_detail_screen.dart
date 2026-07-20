import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
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
                  _SettlementSection(settlement: transaction.settlement),
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

/// Private, merchant-only fiat settlement breakdown. Renders nothing for a
/// plain Bitcoin payment; shows the override explanation when kept in Bitcoin;
/// and "Settlement details unavailable" for anything uninterpretable — never a
/// misleading Bitcoin-only view.
class _SettlementSection extends StatelessWidget {
  final BullnymGetPaidSettlement? settlement;

  const _SettlementSection({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final s = settlement;
    if (s == null ||
        (s.kind == BullnymSettlementKind.bitcoin && s.overrideReason == null)) {
      return const SizedBox.shrink();
    }
    final colors = context.bull;
    final rows = <Widget>[];
    switch (s.kind) {
      case BullnymSettlementKind.unavailable:
        rows.add(
          _DetailRow(
            label: context.loc.getPaidFiatSettlementSectionTitle,
            value: context.loc.getPaidSettlementDetailsUnavailable,
          ),
        );
      case BullnymSettlementKind.bitcoin:
        rows.add(
          Text(
            context.loc.getPaidSettlementOverridden,
            style: context.bullText.bodyMedium?.copyWith(
              color: colors.warning,
            ),
          ),
        );
      case BullnymSettlementKind.mixed:
        for (final btc in s.bitcoin) {
          rows.add(
            _DetailRow(
              label: context.loc.getPaidSettlementBitcoinPortion,
              value: getPaidTransactionAmountText(context, btc.amountSat),
            ),
          );
        }
        rows.addAll(_fiatLegRows(context, s.fiat));
      case BullnymSettlementKind.fiat:
        rows.addAll(_fiatLegRows(context, s.fiat));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(24),
        Text(
          context.loc.getPaidFiatSettlementSectionTitle,
          style: context.bullText.labelMedium?.copyWith(
            color: colors.textMuted,
          ),
        ),
        const Gap(6),
        ...rows,
      ],
    );
  }

  List<Widget> _fiatLegRows(
    BuildContext context,
    List<BullnymFiatSettlementLeg> legs,
  ) {
    final colors = context.bull;
    final rows = <Widget>[];
    for (final leg in legs) {
      final settled =
          leg.status == BullnymSettlementLegStatus.settled &&
          leg.amountMinor != null;
      // Currency is always shown; once settled the value carries the final
      // fiat amount alongside the currency code.
      rows.add(
        _DetailRow(
          label: context.loc.getPaidSettlementLabelFiat,
          value: settled
              ? context.loc.getPaidSettlementFiatAmount(
                  _formatMinor(leg.amountMinor!),
                  leg.currency,
                )
              : leg.currency,
        ),
      );
      rows.add(
        _DetailRow(
          label: context.loc.getPaidSettlementStatus,
          value: _legStatusText(context, leg.status),
        ),
      );
      if (leg.orderId.isNotEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.getPaidSettlementOrderId,
                  style: context.bullText.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                const Gap(6),
                CopyInput(text: leg.orderId),
              ],
            ),
          ),
        );
      }
    }
    return rows;
  }

  String _legStatusText(
    BuildContext context,
    BullnymSettlementLegStatus status,
  ) {
    switch (status) {
      case BullnymSettlementLegStatus.pending:
        return context.loc.getPaidSettlementStatusPending;
      case BullnymSettlementLegStatus.settled:
        return context.loc.getPaidSettlementStatusSettled;
      case BullnymSettlementLegStatus.unavailable:
      case BullnymSettlementLegStatus.unknown:
        return context.loc.getPaidSettlementDetailsUnavailable;
    }
  }

  // Fiat minor units → major.minor with integer arithmetic (never floating
  // point). The seven supported currencies are all 2-decimal.
  String _formatMinor(int minor) {
    final major = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '$major.$cents';
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
