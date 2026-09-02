import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_anchor.dart';
import 'package:bb_mobile/features/transactions/presentation/historical_value.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// What a transaction was worth when it happened.
///
/// The anchor is always stated beside the figure. A bare number would silently
/// claim to be the moment the money moved, and for an incoming on-chain
/// payment that can be hours out.
///
/// Renders nothing when [value] is null. That is the whole unknown-rate
/// behaviour: no placeholder, no explanation, no live-rate fallback, matching
/// `CurrencyText`, which collapses the same way when it has no price.
class HistoricalValueLine extends StatelessWidget {
  const HistoricalValueLine({
    super.key,
    required this.value,
    required this.currencyCode,
    this.isIncoming = true,
    this.showLabel = false,
    this.alignment = CrossAxisAlignment.end,
  });

  final HistoricalValue? value;
  final String currencyCode;
  final bool isIncoming;

  /// The details screen names the figure; the list has no room to.
  final bool showLabel;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) return const SizedBox.shrink();

    final amountStyle = context.font.bodySmall?.copyWith(
      color: context.appColors.onSurface,
      fontWeight: FontWeight.w500,
    );
    final anchorStyle = context.font.labelSmall?.copyWith(
      color: context.appColors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Text(
            isIncoming
                ? context.loc.transactionValueWhenReceived
                : context.loc.transactionValueWhenSent,
            style: anchorStyle,
          ),
        Text(_amountText(context, value), style: amountStyle),
        Text(_anchorText(context, value), style: anchorStyle),
      ],
    );
  }

  String _amountText(BuildContext context, HistoricalValue value) {
    switch (value) {
      case SingleValue(:final fiat):
        return FormatAmount.fiat(fiat, currencyCode);
      case RangeValue(:final low, :final high):
        // One string, never two rows: a range is an admission of uncertainty,
        // not two separate facts.
        return '≈ ${FormatAmount.fiat(low, currencyCode)} – '
            '${FormatAmount.fiat(high, currencyCode)}';
    }
  }

  String _anchorText(BuildContext context, HistoricalValue value) {
    switch (value) {
      case SingleValue(:final at, :final reason):
        final time = _time(at);
        return switch (reason) {
          AnchorReason.sent => context.loc.transactionValueAtSendTime(time),
          AnchorReason.settled => context.loc.transactionValueAtSettleTime(
            time,
          ),
          AnchorReason.confirmed => context.loc.transactionValueAtConfirmTime(
            time,
          ),
        };
      case RangeValue(:final from, :final to):
        return context.loc.transactionValueSentBetween(_time(from), _time(to));
    }
  }

  static String _time(DateTime moment) =>
      DateFormat.Hm().format(moment.toLocal());
}
