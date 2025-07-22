import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onAction,
    this.color,
    this.actionIcon,
    this.bullLogo = false,
  });

  final String title;
  final Function? onBack;
  final Function? onAction;
  final IconData? actionIcon;
  final Color? color;
  final bool bullLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => onBack!(),
              iconSize: 24,
              color: context.colour.secondary,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onAction != null)
            const Gap(40),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.bottomCenter,
              child:
                  bullLogo
                      ? Image.asset(
                        Assets.logos.bbLogoSmall.path,
                        height: 32,
                        width: 32,
                      )
                      : BBText(
                        title,
                        style: context.font.headlineMedium,
                        color: context.colour.secondary,
                      ),
            ),
          ),
          if (onAction != null) ...[
            IconButton(
              icon: Icon(actionIcon ?? Icons.close),
              onPressed: () => onAction!(),
              iconSize: 24,
              color: context.colour.secondary,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onBack != null)
            const Gap(40),
        ],
      ),
    );
  }
}
