import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A generic label chip. **Re-implemented** in `bull_ui` (not imported from
/// `features/labels`, which a package may never depend on — acyclic rule).
///
/// String in, optional leading icon (defaults to a sell tag), optional
/// [onRemove] to show a remove affordance. Truncates with ellipsis.
class BullLabelChip extends StatelessWidget {
  const BullLabelChip({
    super.key,
    required this.label,
    this.icon = BullIcons.sell,
    this.onRemove,
    this.maxWidth = 170,
  });

  /// The chip text.
  final String label;

  /// Leading icon glyph.
  final IconData icon;

  /// When set, renders a trailing remove control that calls this.
  final VoidCallback? onRemove;

  /// Maximum chip width before the label ellipsizes.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.textMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(BullRadius.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullIcon(icon, size: 11, color: colors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: colors.textMuted),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: BullIcon(BullIcons.close, size: 11, color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
