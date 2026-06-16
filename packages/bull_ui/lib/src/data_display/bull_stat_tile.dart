import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Label / value / sub triplet for the summary bar (the design's `Stat`).
/// **New.** Optional [accent] recolours the value (e.g. info-blue when any coin
/// is frozen).
class BullStatTile extends StatelessWidget {
  const BullStatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.accent,
  });

  /// Uppercase caption above the value.
  final String label;

  /// The primary value.
  final String value;

  /// Optional sub-line below the value.
  final String? sub;

  /// Optional colour override for the value.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()], 
            color: accent ?? colors.text,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}
