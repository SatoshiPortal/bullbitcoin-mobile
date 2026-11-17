import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Top bar — back button + centered title + an optional trailing action, with
/// an optional red-dot badge on the trailing action to flag an active filter.
class BullTopBar extends StatelessWidget {
  const BullTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onAction,
    this.actionIcon,
    this.actionBadge = false,
    this.actionTooltip,
    this.color,
    this.titleWidget,
  }) : assert(
         actionIcon == null || actionTooltip != null,
         'A custom actionIcon needs an actionTooltip naming it for screen readers',
       );

  /// The centered title text. Ignored when [titleWidget] is supplied.
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

  /// Accessible name of the trailing action. Defaults to the localized
  /// "Close" when [actionIcon] is null; required with a custom [actionIcon].
  final String? actionTooltip;

  /// Optional background colour. Transparent when null.
  final Color? color;

  /// Replaces the centered [title] text — e.g. a logo. Takes a widget rather
  /// than a flag so the asset stays in the app and out of the design system.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final material = MaterialLocalizations.of(context);
    return Container(
      color: color,
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null)
            IconButton(
              icon: const BullIcon(BullIcons.arrowBack),
              tooltip: material.backButtonTooltip,
              onPressed: onBack,
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
              child:
                  titleWidget ??
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w500)
                          .copyWith(color: colors.text),
                    ),
                  ),
            ),
          ),
          if (onAction != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: BullIcon(actionIcon ?? BullIcons.close),
                  tooltip:
                      actionTooltip ??
                      (actionIcon == null ? material.closeButtonTooltip : null),
                  onPressed: onAction,
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
