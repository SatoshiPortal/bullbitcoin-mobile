import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// Compact icon+label action used inside detail dialogs (Copy, Open in
/// explorer, …) — duplicated from `core/widgets/viewer_action_button.dart`
/// (`ViewerActionButton`).
///
/// Wrapped in an [InkWell] with a 44dp minimum touch target.
class BullViewerActionButton extends StatelessWidget {
  const BullViewerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Leading icon glyph.
  final IconData icon;

  /// Action label.
  final String label;

  /// Tap callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: colors.primary),
              const Gap(4),
              BullText(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                color: colors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
