import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A removable active-filter chip (label + ✕). **New.** Used in the sub-header
/// to show which filters are applied; tapping the ✕ fires [onRemove].
class BullFilterChip extends StatelessWidget {
  const BullFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  /// The filter description.
  final String label;

  /// Fired when the user removes the filter.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(BullRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: colors.primary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: BullIcon(BullIcons.close, size: 13, color: colors.primary),
          ),
        ],
      ),
    );
  }
}
