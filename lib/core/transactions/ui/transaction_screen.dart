import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction_entity.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:bb_mobile/core/transactions/presentation/transaction_cubit.dart';
import 'package:bb_mobile/core/transactions/presentation/transaction_state.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// A reusable transaction confirm/review screen that displays transaction
/// details before broadcasting.
///
/// Styled to match the SendConfirmScreen aesthetic: flat InfoRow layout
/// with thin dividers — not card-based.
///
/// Layout:
/// - **From**: wallet name (via [fromLabel]) or input addresses + amounts
/// - **To**: output addresses + amounts (with copy icon)
/// - **Amount**: total sats + optional fiat equivalent
/// - **Network fees**: fee in sats
/// - **Fee priority**: optional selector widget
///
/// Optional slots allow callers to inject context-specific UI:
/// - [fromLabel] — wallet name shown in the From row (e.g. "Instant payments")
/// - [toLabel] — single recipient label (used when there's one output)
/// - [fiatAmount] — fiat equivalent shown next to the send amount
/// - [feePriorityWidget] — fee priority selector (e.g. fastest/medium/slow)
/// - [topWidget] — custom widget shown above the transaction details
/// - [bottomActions] — action buttons (confirm, broadcast, etc.)
class TransactionScreen extends StatelessWidget {
  const TransactionScreen({
    super.key,
    this.title,
    this.fromLabel,
    this.toLabel,
    this.fiatAmount,
    this.feePriorityWidget,
    this.topWidget,
    this.bottomActions,
  });

  /// Optional title displayed at the top.
  final String? title;

  /// Optional "From" label (e.g. wallet name like "Instant payments").
  /// When provided, shown as the From value instead of input addresses.
  final String? fromLabel;

  /// Optional "To" label (e.g. recipient address or wallet name).
  /// When provided with a single recipient output, used as the To value.
  final String? toLabel;

  /// Optional fiat equivalent string (e.g. "~$42.50 USD").
  final String? fiatAmount;

  /// Optional fee priority selector widget.
  final Widget? feePriorityWidget;

  /// Optional widget shown above the transaction details (e.g. top area icon).
  final Widget? topWidget;

  /// Widget slot for action buttons (confirm, broadcast, etc.)
  /// placed at the bottom of the screen.
  final Widget? bottomActions;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionCubit, TransactionState>(
      builder: (context, state) {
        return switch (state) {
          TransactionInitial() => const _InitialView(),
          TransactionLoading() => const _LoadingView(),
          TransactionLoaded(:final entity) => _LoadedView(
            entity: entity,
            title: title,
            fromLabel: fromLabel,
            toLabel: toLabel,
            fiatAmount: fiatAmount,
            feePriorityWidget: feePriorityWidget,
            topWidget: topWidget,
            bottomActions: bottomActions,
          ),
          TransactionErrorState(:final error) => _ErrorView(error: error),
        };
      },
    );
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FadingLinearProgress(trigger: true),
            const Gap(16),
            Text(context.loc.coreScreensResolvingInputs),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final TransactionError error;

  String _message(BuildContext context) => switch (error) {
    TransactionFetchFailed(:final txid) =>
      context.loc.coreScreensFetchFailed(txid),
    TransactionInputResolutionFailed(:final parentTxId, :final vout) =>
      context.loc.coreScreensInputResolutionFailed(vout, parentTxId),
    TransactionParseFailed(:final message) =>
      context.loc.coreScreensParseFailed(message ?? 'unknown'),
    TransactionNoServersAvailable() =>
      context.loc.coreScreensNoServersAvailable,
    UnexpectedTransactionError(:final message) =>
      context.loc.coreScreensUnexpectedError(message ?? 'unknown'),
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: context.appColors.error, size: 48),
            const Gap(16),
            BBText(
              _message(context),
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.entity,
    this.title,
    this.fromLabel,
    this.toLabel,
    this.fiatAmount,
    this.feePriorityWidget,
    this.topWidget,
    this.bottomActions,
  });

  final TransactionEntity entity;
  final String? title;
  final String? fromLabel;
  final String? toLabel;
  final String? fiatAmount;
  final Widget? feePriorityWidget;
  final Widget? topWidget;
  final Widget? bottomActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topWidget != null) ...[topWidget!, const Gap(16)],
          _SummarySection(
            entity: entity,
            fromLabel: fromLabel,
            toLabel: toLabel,
            fiatAmount: fiatAmount,
            feePriorityWidget: feePriorityWidget,
          ),
          if (bottomActions != null) ...[const Gap(24), bottomActions!],
        ],
      ),
    );
  }
}

// --- Summary section: flat InfoRow layout matching SendConfirmScreen ---

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.entity,
    this.fromLabel,
    this.toLabel,
    this.fiatAmount,
    this.feePriorityWidget,
  });

  final TransactionEntity entity;
  final String? fromLabel;
  final String? toLabel;
  final String? fiatAmount;
  final Widget? feePriorityWidget;

  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final recipientOutputs = entity.recipientOutputs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- From section ---
        _buildFromSection(context),
        _divider(context),

        // --- To section ---
        _buildToSection(context, recipientOutputs),
        _divider(context),

        // --- Amount row ---
        _InfoRow(
          label: context.loc.coreScreensAmountLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BBText(
                entity.sendAmountSat != null
                    ? '${_formatSats(entity.sendAmountSat!)} sats'
                    : '${_formatSats(entity.totalOutputsSat)} sats',
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
              ),
              if (fiatAmount != null)
                BBText(
                  fiatAmount!,
                  style: context.font.labelSmall,
                  color: context.appColors.onSurfaceVariant,
                ),
            ],
          ),
        ),
        _divider(context),

        // --- Network fees row ---
        _InfoRow(
          label: context.loc.coreScreensNetworkFeesLabel,
          child: BBText(
            '${_formatSats(entity.feeSat)} sats',
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
            textAlign: TextAlign.end,
          ),
        ),

        // --- Fee rate row (optional) ---
        if (entity.feeRate != null) ...[
          _divider(context),
          _InfoRow(
            label: context.loc.coreScreensFeeRateLabel,
            child: BBText(
              context.loc.coreScreensFeeRateValue(
                entity.feeRate!.toStringAsFixed(1),
              ),
              style: context.font.bodyLarge,
              color: context.appColors.secondary,
              textAlign: TextAlign.end,
            ),
          ),
        ],

        // --- Fee priority widget slot (optional) ---
        if (feePriorityWidget != null) ...[
          _divider(context),
          feePriorityWidget!,
        ],
        _divider(context),

        // --- Change unknown info — only for external transactions ---
        if (!entity.hasChange)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: context.appColors.onSurfaceVariant,
                ),
                const Gap(4),
                Expanded(
                  child: BBText(
                    context.loc.coreScreensChangeOutputUnknown,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Build the From section.
  /// If [fromLabel] is provided, show wallet name.
  /// Otherwise, show each input address + amount.
  Widget _buildFromSection(BuildContext context) {
    if (fromLabel != null) {
      // Wallet name provided — simple row
      return _InfoRow(
        label: context.loc.coreScreensFromLabel,
        child: BBText(
          fromLabel!,
          style: context.font.bodyLarge,
          color: context.appColors.secondary,
          textAlign: TextAlign.end,
        ),
      );
    }

    // No wallet name — show input addresses + amounts
    final inputs = entity.resolvedInputs;
    if (inputs.isEmpty) {
      return _InfoRow(
        label: context.loc.coreScreensFromLabel,
        child: BBText(
          context.loc.coreScreensUnknown,
          style: context.font.bodyLarge,
          color: context.appColors.onSurfaceVariant,
          textAlign: TextAlign.end,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            context.loc.coreScreensFromLabel,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final input in inputs) _InputAddressRow(input: input),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the To section.
  /// Shows each recipient output with address + amount.
  /// If [toLabel] is provided and there's a single recipient, use it.
  Widget _buildToSection(
    BuildContext context,
    List<TxOutput> recipientOutputs,
  ) {
    // Single recipient with toLabel provided — use the simple layout
    if (toLabel != null && recipientOutputs.length == 1) {
      return _InfoRow(
        label: context.loc.coreScreensToLabel,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: BBText(
                toLabel!,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
                textAlign: TextAlign.end,
                maxLines: 5,
              ),
            ),
            const Gap(4),
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: toLabel!)),
              child: Icon(
                Icons.copy,
                color: context.appColors.primary,
                size: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Multiple outputs or no toLabel — show each output with address + amount
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            context.loc.coreScreensToLabel,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final output in recipientOutputs)
                  _OutputAddressRow(output: output),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Individual input address row ---

class _InputAddressRow extends StatelessWidget {
  const _InputAddressRow({required this.input});

  final ResolvedInput input;

  @override
  Widget build(BuildContext context) {
    final displayAddress =
        input.address ?? StringFormatting.truncateMiddle(input.previousTxId);
    final copyText = input.address ?? input.previousTxId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: BBText(
                  displayAddress,
                  style: context.font.bodySmall,
                  color: context.appColors.secondary,
                  textAlign: TextAlign.end,
                  maxLines: 3,
                ),
              ),
              const Gap(4),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: copyText)),
                child: Icon(
                  Icons.copy,
                  color: context.appColors.primary,
                  size: 14,
                ),
              ),
            ],
          ),
          BBText(
            '${_formatSats(input.valueSat)} sats',
            style: context.font.labelSmall,
            color: context.appColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// --- Individual output address row ---

class _OutputAddressRow extends StatelessWidget {
  const _OutputAddressRow({required this.output});

  final TxOutput output;

  @override
  Widget build(BuildContext context) {
    final address = output.address;
    final displayAddress =
        address ?? StringFormatting.truncateMiddle(output.scriptPubKeyHex);
    final copyText = address ?? output.scriptPubKeyHex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: BBText(
                  displayAddress,
                  style: context.font.bodySmall,
                  color: context.appColors.secondary,
                  textAlign: TextAlign.end,
                  maxLines: 3,
                ),
              ),
              const Gap(4),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: copyText)),
                child: Icon(
                  Icons.copy,
                  color: context.appColors.primary,
                  size: 14,
                ),
              ),
            ],
          ),
          BBText(
            '${_formatSats(output.valueSat)} sats',
            style: context.font.labelSmall,
            color: context.appColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// --- Shared Widgets ---

/// A flat info row matching the send confirm screen pattern:
/// label on the left, value widget on the right, with vertical padding.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            label,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Format satoshis with thousand separators for readability.
String _formatSats(int sats) {
  if (sats < 0) return '-${_formatSats(-sats)}';
  final str = sats.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}
