import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum _ButtonSize { small, large }

class BBButton extends StatelessWidget {
  const BBButton.big({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    required this.bgColor,
    required this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
  }) : size = _ButtonSize.large;

  const BBButton.small({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    required this.bgColor,
    required this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
  }) : size = _ButtonSize.small;

  final String? icon;
  final IconData? iconData;

  final String label;
  final Color bgColor;
  final Color textColor;
  final bool iconFirst;
  final Function onPressed;
  final bool outlined;
  final _ButtonSize size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size == _ButtonSize.large ? 2 : 2);

    final image = iconData != null
        ? Icon(iconData, size: 20, color: textColor)
        : Image.asset(icon!, width: 20, height: 20, color: textColor);

    return InkWell(
      onTap: () => onPressed(),
      borderRadius: radius,
      child: Container(
        height: 52,
        width: size == _ButtonSize.large ? null : 160,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: !outlined ? bgColor : Colors.transparent,
          border: outlined ? Border.all(color: bgColor) : null,
          borderRadius: radius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconFirst) ...[
              image,
              const Gap(10),
              BBText(
                label,
                style: context.font.headlineLarge,
                color: textColor,
              ),
            ] else ...[
              BBText(
                label,
                style: context.font.headlineLarge,
                color: textColor,
              ),
              const Gap(10),
              image,
            ],
          ],
        ),
      ),
    );
  }
}
