import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';

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
    this.backEnabled = true,
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
  final bool backEnabled;

  @override
  Widget build(BuildContext context) {
    final leading = onBack == null
        ? null
        : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: backEnabled ? () => onBack!() : null,
            iconSize: 24,
            color: context.appColors.onSurface,
            visualDensity: VisualDensity.compact,
          );
    final trailing =
        action ??
        (onAction == null
            ? null
            : IconButton(
                icon: Icon(actionIcon ?? Icons.close),
                onPressed: () => onAction!(),
                iconSize: 24,
                color: context.appColors.onSurface,
                visualDensity: VisualDensity.compact,
              ));

    return Container(
      color: color,
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 48,
          child: NavigationToolbar(
            leading: leading,
            middle: bullLogo
                ? Image.asset(
                    Assets.logos.bbLogoSmall.path,
                    height: 32,
                    width: 32,
                  )
                : BBText(
                    title,
                    style: context.font.headlineMedium,
                    color: context.appColors.onSurface,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
            trailing: trailing,
            centerMiddle: true,
            middleSpacing: 8,
          ),
        ),
      ),
    );
  }
}
