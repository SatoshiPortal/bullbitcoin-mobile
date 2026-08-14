import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_failure_l10n.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
class TransactionReviewView extends StatelessWidget {
  const TransactionReviewView({
    super.key,
    this.title,
    this.fromLabel,
    this.toLabel,
    this.fiatAmount,
    this.feePriorityWidget,
    this.topWidget,
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionReviewCubit, TransactionReviewState>(
      builder: (context, state) {
        return switch (state) {
          TransactionReviewInitial() => const _InitialView(),
          TransactionReviewLoading() => const _LoadingView(),
          TransactionReviewLoaded(:final transaction) => _LoadedView(
            transaction: transaction,
            title: title,
            fromLabel: fromLabel,
            toLabel: toLabel,
            fiatAmount: fiatAmount,
            feePriorityWidget: feePriorityWidget,
            topWidget: topWidget,
          ),
          TransactionReviewErrorState(:final failure) => _ErrorView(
            failure: failure,
          ),
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
  const _ErrorView({required this.failure});

  final TransactionReviewFailure failure;

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
              failure.toTranslated(context),
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
    required this.transaction,
    this.title,
    this.fromLabel,
    this.toLabel,
    this.fiatAmount,
    this.feePriorityWidget,
    this.topWidget,
  });

  final ReviewableTransaction transaction;
  final String? title;
  final String? fromLabel;
  final String? toLabel;
  final String? fiatAmount;
  final Widget? feePriorityWidget;
  final Widget? topWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topWidget != null) ...[topWidget!, const Gap(16)],
          _SummarySection(
            transaction: transaction,
            fromLabel: fromLabel,
            toLabel: toLabel,
            fiatAmount: fiatAmount,
            feePriorityWidget: feePriorityWidget,
          ),
        ],
      ),
    );
  }
}

// --- Summary section: flat InfoRow layout matching SendConfirmScreen ---

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.transaction,
    this.fromLabel,
    this.toLabel,
    this.fiatAmount,
    this.feePriorityWidget,
  });

  final ReviewableTransaction transaction;
  final String? fromLabel;
  final String? toLabel;
  final String? fiatAmount;
  final Widget? feePriorityWidget;

  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final recipientOutputs = transaction.recipientOutputs;

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
                transaction.sendAmountSat != null
                    ? '${_formatSats(transaction.sendAmountSat!)} sats'
                    : '${_formatSats(transaction.totalOutputsSat)} sats',
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
            transaction.feeSat != null
                ? '${_formatSats(transaction.feeSat!)} sats'
                : context.loc.mempoolServerStatusUnknown,
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
            textAlign: TextAlign.end,
          ),
        ),

        // --- Fee rate row (optional) ---
        if (transaction.feeRate != null) ...[
          _divider(context),
          _InfoRow(
            label: context.loc.coreScreensFeeRateLabel,
            child: BBText(
              context.loc.coreScreensFeeRateValue(
                transaction.feeRate!.toStringAsFixed(1),
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
        if (!transaction.hasChange)
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
    final inputs = transaction.resolvedInputs;
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
        child: Align(
          alignment: Alignment.centerRight,
          child: AddressViewer(
            toLabel!,
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
          ),
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
    final fullAddress = input.address ?? input.previousTxId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: double.infinity,
            child: AddressViewer(
              fullAddress,
              style: context.font.bodySmall,
              color: context.appColors.secondary,
            ),
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
    final fullAddress = output.address ?? output.scriptPubKeyHex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: double.infinity,
            child: AddressViewer(
              fullAddress,
              style: context.font.bodySmall,
              color: context.appColors.secondary,
            ),
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
