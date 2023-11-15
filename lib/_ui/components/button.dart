import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

enum _ButtonType {
  smallRed,
  smallBlack,
  bigRed,
  bigBlack,
  text,
  textWithRightArrow,
  textWithLeftArrow,
  textWithStatusAndRightArrow,
}

class BBButton extends StatelessWidget {
  const BBButton.smallRed({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.smallRed,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null;

  const BBButton.smallBlack({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.smallBlack,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null;

  const BBButton.bigRed({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.bigRed,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null;

  const BBButton.bigBlack({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.bigBlack,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null;

  const BBButton.text({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingText,
    this.disabled = false,
    this.isRed = false,
    this.isBlue = true,
    this.centered = false,
  })  : type = _ButtonType.text,
        filled = false,
        statusText = null;

  const BBButton.textWithRightArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.textWithRightArrow,
        filled = false,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null;

  const BBButton.textWithLeftArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.textWithLeftArrow,
        filled = false,
        isBlue = null,
        isRed = null,
        statusText = null,
        centered = null;

  const BBButton.textWithStatusAndRightArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
    this.isBlue = false,
    this.isRed = false,
    this.statusText,
  })  : type = _ButtonType.textWithStatusAndRightArrow,
        filled = false,
        centered = null;

  final String label;
  final String? statusText;
  final bool? isRed;
  final bool? isBlue;
  final Function onPressed;
  final bool filled;
  final bool disabled;
  final bool? centered;
  final _ButtonType type;

  final bool loading;
  final String? loadingText;

  @override
  Widget build(BuildContext context) {
    Widget widget;

    switch (type) {
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

      case _ButtonType.bigRed:
        final style = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: context.colour.primary),
          backgroundColor: filled ? context.colour.primary : context.colour.background,
          elevation: 6,
          shadowColor: context.colour.background,
        );

        if (!loading)
          widget = OutlinedButton(
            style: style,
            onPressed: disabled ? null : () => onPressed(),
            child: BBText.titleLarge(
              label,
              isRed: !filled,
              onSurface: filled,
            ),
          );
        else {
          widget = OutlinedButton(
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
                BBText.titleLarge(
                  loadingText ?? label,
                  isRed: !filled,
                  onSurface: filled,
                ),
              ],
            ),
          );
        }

      case _ButtonType.bigBlack:
        final isDark =
            context.select((Lighting _) => _.state.currentTheme(context) == ThemeMode.dark);

        final style = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
          backgroundColor: !isDark ? context.colour.onBackground : context.colour.surface,
          foregroundColor: context.colour.onPrimary,
        );

        widget = TextButton(
          style: style,
          onPressed: disabled ? null : () => onPressed(),
          child: BBText.titleLarge(label, onSurface: filled),
        );

      case _ButtonType.smallRed:
        final style = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: context.colour.primary),
          backgroundColor: filled ? context.colour.primary : context.colour.background,
          elevation: 6,
          shadowColor: context.colour.background,
        );

        widget = OutlinedButton(
          style: style,
          onPressed: disabled ? null : () => onPressed(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BBText.title(
              label,
              isRed: !filled,
              onSurface: filled,
            ),
          ),
        );

      case _ButtonType.smallBlack:
        final style = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: const StadiumBorder(),
          backgroundColor: context.colour.onBackground,
          foregroundColor: context.colour.onPrimary,
        );

        widget = TextButton(
          style: style,
          onPressed: disabled ? null : () => onPressed(),
          child: BBText.titleLarge(label, onSurface: filled, isBold: true),
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
              ),
              if (centered ?? false) const Spacer(),
            ],
          ),
        );

      case _ButtonType.textWithRightArrow:
        widget = TextButton(
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
