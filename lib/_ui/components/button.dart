import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
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
}

class BBButton extends StatelessWidget {
  const BBButton.smallRed({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  }) : type = _ButtonType.smallRed;

  const BBButton.smallBlack({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  }) : type = _ButtonType.smallBlack;

  const BBButton.bigRed({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  }) : type = _ButtonType.bigRed;

  const BBButton.bigBlack({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.filled = false,
    this.loading = false,
    this.loadingText,
  }) : type = _ButtonType.bigBlack;

  const BBButton.text({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingText,
    this.disabled = false,
  })  : type = _ButtonType.text,
        filled = false;

  const BBButton.textWithRightArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.textWithRightArrow,
        filled = false;

  const BBButton.textWithLeftArrow({
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.loadingText,
  })  : type = _ButtonType.textWithLeftArrow,
        filled = false;

  final String label;
  final Function onPressed;
  final bool filled;
  final bool disabled;
  final _ButtonType type;

  final bool loading;
  final String? loadingText;

  @override
  Widget build(BuildContext context) {
    Widget widget;

    switch (type) {
      case _ButtonType.bigRed:
        final style = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: context.colour.primary),
          backgroundColor: filled ? context.colour.primary : context.colour.background,
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
                    valueColor: AlwaysStoppedAnimation<Color>(context.colour.onPrimary),
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
        final style = OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
          backgroundColor: context.colour.onBackground,
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: const StadiumBorder(),
          backgroundColor: context.colour.onBackground,
          foregroundColor: context.colour.onPrimary,
        );

        widget = TextButton(
          style: style,
          onPressed: disabled ? null : () => onPressed(),
          child: BBText.titleLarge(label, onSurface: filled),
        );

      case _ButtonType.text:
        widget = TextButton(
          onPressed: disabled ? null : () => onPressed(),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: BBText.body(label, isBlue: true),
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
