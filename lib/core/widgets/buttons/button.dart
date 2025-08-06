import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
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
    this.borderColor,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
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
    this.borderColor,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
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
  final Color? borderColor;
  final bool disabled;
  final double? height;
  final double? width;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size == _ButtonSize.large ? 2 : 2);

    final image =
        iconData != null
            ? Icon(iconData, size: 20, color: textColor)
            : icon != null
            ? Image.asset(icon!, width: 20, height: 20, color: textColor)
            : const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: InkWell(
          onTap: () => disabled ? null : onPressed(),
          borderRadius: radius,
          child: Container(
            height: height ?? 52,
            width: width ?? (size == _ButtonSize.large ? null : 160),
            padding:
                height != null
                    ? null
                    : const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: !outlined ? bgColor : Colors.transparent,
              border: outlined ? Border.all(color: textColor) : null,
              borderRadius: radius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconData == null && icon == null) ...[
                  BBText(
                    label,
                    style: textStyle ?? context.font.headlineLarge,
                    color: textColor,
                  ),
                ] else ...[
                  if (iconFirst) ...[
                    image,
                    const Gap(10),
                    BBText(
                      label,
                      style: textStyle ?? context.font.headlineLarge,
                      color: textColor,
                    ),
                  ] else ...[
                    BBText(
                      label,
                      style: textStyle ?? context.font.headlineLarge,
                      color: textColor,
                    ),
                    const Gap(10),
                    image,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
