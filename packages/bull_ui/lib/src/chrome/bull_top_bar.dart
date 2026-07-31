import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Top bar — back button + centered title + an optional trailing action.
///
/// Duplicated from `core/widgets/navbar/top_bar.dart` (the `BB*` original is
/// left untouched). Adds an optional red-dot badge on the trailing action to
/// flag an active filter.
class BullTopBar extends StatelessWidget {
  const BullTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onAction,
    this.actionIcon,
    this.actionBadge = false,
  });

  /// The centered title text.
  final String title;

  /// Back-button callback. When null, no back button is shown.
  final VoidCallback? onBack;

  /// Trailing-action callback. When null, no trailing action is shown.
  final VoidCallback? onAction;

  /// Trailing-action icon (e.g. `BullIcons.tune`). Defaults to a close icon.
  final IconData? actionIcon;

  /// When true, paints a small red dot over the trailing action — used to flag
  /// that a filter is currently active.
  final bool actionBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null)
            IconButton(
              icon: const BullIcon(BullIcons.arrowBack),
              onPressed: onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              iconSize: 24,
              color: colors.text,
              visualDensity: VisualDensity.compact,
            )
          else if (onAction != null)
            const SizedBox(width: 40),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.bottomCenter,
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: colors.text),
              ),
            ),
          ),
          if (onAction != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: BullIcon(actionIcon ?? BullIcons.close),
                  onPressed: onAction,
                  tooltip: actionIcon == null
                      ? MaterialLocalizations.of(context).closeButtonTooltip
                      : null,
                  iconSize: 24,
                  color: colors.text,
                  visualDensity: VisualDensity.compact,
                ),
                if (actionBadge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            )
          else if (onBack != null)
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
