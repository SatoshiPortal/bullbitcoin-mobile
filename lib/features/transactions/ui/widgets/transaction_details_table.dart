import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/transaction_viewer.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/labels_table_item.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/progress_steps_indicator.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Dumb renderer: maps a [TransactionDetailViewModel] onto the shared
/// [DetailsTable]/[DetailsTableItem] widgets. It knows nothing about swaps,
/// orders, payjoins or any future mechanism — only about the view model.
class TransactionDetailsTable extends StatelessWidget {
  const TransactionDetailsTable({super.key, required this.view});

  final TransactionDetailViewModel view;

  @override
  Widget build(BuildContext context) {
    return DetailsTable(
      items: [
        if (view.progress != null) _statusRow(context, view.progress!),
        for (final row in view.rows) _item(context, row),
      ],
    );
  }

  Widget _statusRow(BuildContext context, TxProgressView progress) {
    return DetailsTableItem(
      label: progress.label,
      displayValue: progress.summaryLabel,
      expandableChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(4),
          ProgressStepsIndicator(
            steps: progress.steps,
            currentStep: progress.currentStep,
            isFailedOrExpired: progress.state == TxProgressState.failed,
          ),
          if (progress.detailMessage != null) ...[
            const Gap(4),
            BBText(
              progress.detailMessage!,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.secondary,
              ),
              maxLines: 5,
            ),
          ],
        ],
      ),
    );
  }

  Widget _item(BuildContext context, TxDetailRow row) {
    if (row.value is TxLabels) {
      return LabelsTableItem(
        title: row.label,
        labels: (row.value as TxLabels).labels,
      );
    }

    final hasExpansion = row.expandedRows.isNotEmpty || row.expandedNote != null;

    return DetailsTableItem(
      label: row.label,
      displayValue: row.value is TxText ? (row.value as TxText).text : null,
      displayWidget: _valueWidget(context, row.value),
      copyValue: row.copyValue,
      expandableChild: hasExpansion ? _expansion(context, row) : null,
    );
  }

  Widget _expansion(BuildContext context, TxDetailRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(4),
        if (row.expandedNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BBText(
              row.expandedNote!,
              style: context.font.labelSmall,
              color: context.appColors.secondary,
            ),
          ),
        for (final sub in row.expandedRows) _item(context, sub),
        const Gap(4),
      ],
    );
  }

  /// Returns the custom value widget, or null to fall back to the row's
  /// plain [DetailsTableItem.displayValue] string (used for [TxText]).
  Widget? _valueWidget(BuildContext context, TxValue value) {
    switch (value) {
      case TxText():
        return null;
      case TxAmount(:final sats):
        return CurrencyText(
          sats,
          showFiat: false,
          style: context.font.bodyLarge,
          color: context.appColors.onSurface,
        );
      case TxFiat(:final amount, :final currency):
        return CurrencyText(
          0,
          showFiat: false,
          fiatAmount: amount,
          fiatCurrency: currency,
          style: context.font.bodyLarge,
          color: context.appColors.onSurface,
        );
      case TxId(:final txid, :final isLiquid, :final isTestnet, :final unblindedUrl):
        return isLiquid
            ? TransactionViewer.liquid(
                txid,
                style: TextStyle(color: context.appColors.primary),
                isTestnet: isTestnet,
                unblindedUrl: unblindedUrl,
              )
            : TransactionViewer.bitcoin(
                txid,
                style: TextStyle(color: context.appColors.primary),
                isTestnet: isTestnet,
              );
      case TxAddress(:final address):
        return AddressViewer(
          address,
          style: TextStyle(color: context.appColors.onSurface),
        );
      case TxLabels():
        return null;
    }
  }
}
