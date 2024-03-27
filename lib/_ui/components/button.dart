import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

enum _ButtonType {
  big,
  text,
  textWithRightArrow,
  textWithLeftArrow,
  textWithStatusAndRightArrow,
}

class BBButton extends StatelessWidget {
  const BBButton.big({
    required this.label,
    required this.onPressed,
    this.leftIcon,
    this.buttonKey,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
    this.fillWidth = false,
    this.leftSvgAsset,
  })  : type = _ButtonType.big,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null,
        onSurface = null,
        fontSize = null;

  const BBButton.text({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingText,
    this.disabled = false,
    this.isRed = false,
    this.isBlue = true,
    this.centered = false,
    this.buttonKey,
    this.onSurface = false,
    this.fontSize,
  })  : type = _ButtonType.text,
        filled = false,
        statusText = null,
        leftIcon = null,
        leftSvgAsset = null,
        fillWidth = true;

  const BBButton.textWithRightArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
    this.buttonKey,
  })  : type = _ButtonType.textWithRightArrow,
        filled = false,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null,
        leftSvgAsset = null,
        leftIcon = null,
        fillWidth = true,
        onSurface = null,
        fontSize = null;

  const BBButton.textWithLeftArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
    this.buttonKey,
  })  : type = _ButtonType.textWithLeftArrow,
        filled = false,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null,
        leftIcon = null,
        leftSvgAsset = null,
        fillWidth = true,
        onSurface = null,
        fontSize = null;

  const BBButton.textWithStatusAndRightArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
    this.isBlue = false,
    this.isRed = false,
    this.statusText,
    this.buttonKey,
  })  : type = _ButtonType.textWithStatusAndRightArrow,
        filled = false,
        centered = null,
        leftIcon = null,
        leftSvgAsset = null,
        fillWidth = true,
        onSurface = null,
        fontSize = null;

  final String label;
  final String? statusText;
  final bool? isRed;
  final bool? isBlue;
  final Function onPressed;
  final bool filled;
  final bool disabled;
  final bool? centered;
  final _ButtonType type;
  final IconData? leftIcon;
  final String? leftSvgAsset;
  final bool fillWidth;
  final double? fontSize;
  final bool? onSurface;

  final bool loading;
  final String? loadingText;

  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final darkMode =
        context.select((Lighting x) => x.state.currentTheme(context) == ThemeMode.dark);

    final bgColour = darkMode ? context.colour.background : NewColours.offWhite;

    Widget widget;

    switch (type) {
      case _ButtonType.big:
        final style = ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: const BorderSide(color: Colors.white),
          shadowColor: Colors.black12,
          backgroundColor: bgColour,
          surfaceTintColor: bgColour,
          elevation: 4,
          // shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),

          // disabledForegroundColor: context.colour.onBackground,
        );

        if (!loading)
          widget = ElevatedButton(
            key: buttonKey,
            style: style,
            onPressed: disabled ? null : () => onPressed(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leftSvgAsset != null) ...[
                  SvgPicture.asset(
                    leftSvgAsset!,
                    colorFilter: ColorFilter.mode(
                      context.colour.onBackground,
                      BlendMode.srcIn,
                    ),
                  ),
                  const Gap(16),
                ] else if (leftIcon != null) ...[
                  Icon(
                    leftIcon,
                    color: context.colour.onBackground,
                  ),
                  const Gap(16),
                ],
                BBText.titleLarge(label, fontSize: 16),
              ],
            ),
          );
        else {
          widget = ElevatedButton(
            style: style,
            onPressed: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Gap(8),
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(context.colour.primary),
                  ),
                ),
                const Gap(8),
                BBText.title(
                  loadingText ?? label,
                  isRed: !filled,
                  onSurface: filled,
                ),
              ],
            ),
          );
        }

        widget = Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(8.0),
            ),
            boxShadow: [
              BoxShadow(
                color: !disabled ? Colors.black.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            height: 45,
            width: fillWidth ? null : 225,
            child: widget,
          ),
        );

      case _ButtonType.textWithStatusAndRightArrow:
        widget = TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: disabled ? null : () => onPressed(),
          child: Row(
            // crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BBText.body(label),
              const Spacer(),
              if (statusText != null)
                AnimatedSwitcher(
                  duration: 600.ms,
                  child: !loading
                      ? BBText.title(
                          statusText!,
                          isBold: true,
                          isBlue: isBlue ?? false,
                          isRed: isRed ?? false,
                        )
                      : SizedBox(
                          height: 8,
                          width: 66,
                          child: LinearProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(context.colour.primary),
                            backgroundColor: context.colour.background,
                          ),
                        ),
                ),
              const Gap(8),
              FaIcon(
                FontAwesomeIcons.angleRight,
                color: context.colour.onBackground,
                // size: 16,
              ),
              const Gap(8),
            ],
          ),
        );

      case _ButtonType.text:
        widget = TextButton(
          onPressed: disabled ? null : () => onPressed(),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Row(
            children: [
              if (centered ?? false) const Spacer(),
              BBText.body(
                label,
                isBlue: isBlue ?? false,
                isRed: isRed ?? false,
                fontSize: fontSize,
                onSurface: onSurface ?? false,
              ),
              if (centered ?? false) const Spacer(),
            ],
          ),
        );

      case _ButtonType.textWithRightArrow:
        widget = TextButton(
          key: buttonKey,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: disabled ? null : () => onPressed(),
          child: Row(
            children: [
              BBText.title(label, isBlue: true),
              const Gap(8),
              FaIcon(
                FontAwesomeIcons.angleRight,
                color: context.colour.secondary,
                size: 16,
              ),
            ],
          ),
        );

      case _ButtonType.textWithLeftArrow:
        widget = TextButton(
          onPressed: disabled ? null : () => onPressed(),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.angleRight,
                color: context.colour.secondary,
                size: 16,
              ),
              const Gap(8),
              BBText.title(label, isBlue: true),
            ],
          ),
        );
    }

    return IgnorePointer(
      ignoring: disabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: widget,
        ),
      ),
    );
  }
}
