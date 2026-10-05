import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A removable active-filter chip (label + ✕). **New.** Used in the sub-header
/// to show which filters are applied; tapping the ✕ fires [onRemove].
class BullFilterChip extends StatelessWidget {
  const BullFilterChip({super.key, required this.label, required this.onRemove})
    : selected = null,
      onSelected = null,
      selectionColor = null;

  const BullFilterChip.selectable({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectionColor,
  }) : onRemove = null;

  /// The filter description.
  final String label;

  /// Fired when the user removes the filter.
  final VoidCallback? onRemove;
  final bool? selected;
  final ValueChanged<bool>? onSelected;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final child = Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(BullRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          if (onSelected == null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: BullIcon(BullIcons.close, size: 13, color: colors.primary),
            ),
          ],
        ],
      ),
    );
    if (onSelected == null) return child;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => onSelected!(!selected!),
        borderRadius: BorderRadius.circular(BullRadius.full),
        child: Container(
          decoration: BoxDecoration(
            color:
                (selected!
                        ? (selectionColor ?? colors.primary)
                        : colors.surface)
                    .withValues(alpha: selected! ? 0.2 : 1),
            border: Border.all(
              color: selected!
                  ? (selectionColor ?? colors.primary)
                  : colors.border,
            ),
            borderRadius: BorderRadius.circular(BullRadius.full),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected!
                  ? (selectionColor ?? colors.primary)
                  : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
