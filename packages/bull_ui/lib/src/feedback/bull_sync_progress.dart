import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// The visual state a [BullSyncProgress] renders — independent of the
/// backend driving it (Electrum, compact block filters, or anything else
/// that reports a wallet sync's progress).
enum BullSyncProgressStatus {
  /// This stage has not started yet. The bar renders empty and muted.
  pending,

  /// A sync is in flight. [BullSyncProgress.percent] may or may not be
  /// known yet — an indeterminate bar is shown when it is null.
  active,

  /// The sync finished successfully. The bar renders full and coloured
  /// [BullTheme.success].
  completed,

  /// The sync stopped on a failure. The bar renders full and coloured
  /// [BullTheme.error]; [label] is expected to already be a generic,
  /// translated message — this widget never renders a raw error string.
  failed,
}

/// A labeled progress bar for a long-running sync, with an optional
/// determinate percent and an accessible semantic label.
///
/// Theme-only: every colour comes from [BullThemeX.bull], nothing
/// hardcoded. Reusable wherever a feature needs to show a wallet (or other)
/// sync's advisory progress — not specific to any one sync backend.
class BullSyncProgress extends StatelessWidget {
  const BullSyncProgress({
    super.key,
    required this.label,
    this.status = BullSyncProgressStatus.active,
    this.percent,
    this.semanticLabel,
  }) : assert(
         percent == null || (percent >= 0 && percent <= 100),
         'percent must be within 0-100',
       );

  /// Short status text shown above the bar (e.g. "Connecting to peers…").
  final String label;

  /// Which visual state to render — see [BullSyncProgressStatus].
  final BullSyncProgressStatus status;

  /// A determinate 0-100 estimate, or null for an indeterminate bar.
  /// Ignored when [status] is not [BullSyncProgressStatus.active].
  final double? percent;

  /// Overrides [label] for accessibility tools; defaults to [label] itself.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final barColor = switch (status) {
      BullSyncProgressStatus.pending => colors.textMuted,
      BullSyncProgressStatus.active => colors.primary,
      BullSyncProgressStatus.completed => colors.success,
      BullSyncProgressStatus.failed => colors.error,
    };
    final barValue = switch (status) {
      BullSyncProgressStatus.pending => 0.0,
      BullSyncProgressStatus.active =>
        percent == null ? null : (percent! / 100).clamp(0.0, 1.0),
      BullSyncProgressStatus.completed || BullSyncProgressStatus.failed => 1.0,
    };

    return Semantics(
      label: semanticLabel ?? label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.bullText.bodyMedium?.copyWith(
                    color: colors.text,
                  ),
                ),
              ),
              if (status == BullSyncProgressStatus.active && percent != null)
                Text(
                  '${percent!.round()}%',
                  style: context.bullText.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barValue,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}
