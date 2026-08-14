import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onAction,
    this.color,
    this.actionIcon,
    this.action,
    this.bullLogo = false,
  });

  final String title;
  final Function? onBack;
  final Function? onAction;
  final IconData? actionIcon;

  /// Optional custom trailing widget on the right of the bar. Used instead of
  /// [onAction]/[actionIcon] when the trailing affordance isn't a plain icon
  /// button (e.g. the receive screen's payjoin toggle chip).
  final Widget? action;
  final Color? color;
  final bool bullLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        crossAxisAlignment: .end,
        children: [
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => onBack!(),
              iconSize: 24,
              color: context.appColors.onSurface,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onAction != null || action != null)
            const Gap(40),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.bottomCenter,
              child: bullLogo
                  ? Image.asset(
                      Assets.logos.bbLogoSmall.path,
                      height: 32,
                      width: 32,
                    )
                  : BBText(
                      title,
                      style: context.font.headlineMedium,
                      color: context.appColors.onSurface,
                    ),
            ),
          ),
          if (action != null) ...[
            // No extra bottom padding here (unlike the title's Container,
            //  which needs it because it has none of its own): the action
            //  widget is expected to carry its own internal padding, same as
            //  the plain IconButton case below (Material's default padding),
            //  so its bottom aligns with the title/icon without a second
            //  offset stacking on top of it.
            action!,
          ] else if (onAction != null) ...[
            IconButton(
              icon: Icon(actionIcon ?? Icons.close),
              onPressed: () => onAction!(),
              iconSize: 24,
              color: context.appColors.onSurface,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onBack != null)
            const Gap(40),
        ],
      ),
    );
  }
}
