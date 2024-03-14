import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';

enum _FontTypes {
  headline,
  titleLarge,
  titleSmall,
  title,
  body,
  bodySmall,
  bodyBold,
  error,
  errorSmall,
}

class BBText extends StatelessWidget {
  const BBText.headline(
    this.text, {
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  })  : type = _FontTypes.headline,
        textAlign = TextAlign.left;

  const BBText.titleLarge(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.titleLarge;

  const BBText.title(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.title;

  const BBText.body(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.body;

  const BBText.bodySmall(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.bodySmall;

  const BBText.bodyBold(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = true,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.body;

  const BBText.error(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.isGreen = false,
    this.removeColourOpacity = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.error;

  const BBText.errorSmall(
    this.text, {
    this.textAlign = TextAlign.left,
    this.onSurface = false,
    this.isBold = false,
    this.isRed = false,
    this.isBlue = false,
    this.removeColourOpacity = false,
    this.isGreen = false,
    this.fontSize,
    this.uiKey,
    this.compact = false,
  }) : type = _FontTypes.errorSmall;

  final String text;
  final _FontTypes type;
  final TextAlign textAlign;
  final bool onSurface;
  final bool isBold;
  final bool isRed;
  final bool isBlue;
  final bool isGreen;
  final bool removeColourOpacity;
  final Key? uiKey;
  final double? fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    TextStyle style;

    switch (type) {
      case _FontTypes.headline:
        style = context.font.headlineSmall!;
      case _FontTypes.titleLarge:
        style = context.font.labelLarge!.copyWith(fontSize: 20);
      case _FontTypes.titleSmall:
        style = context.font.labelSmall!;
      case _FontTypes.title:
        style = context.font.labelLarge!;
      case _FontTypes.body:
        style = context.font.bodyLarge!;
      case _FontTypes.bodySmall:
        style = context.font.bodySmall!;
      case _FontTypes.bodyBold:
        style = context.font.bodyLarge!;
      case _FontTypes.error:
        style = context.font.bodyMedium!.copyWith(color: context.colour.error);
      case _FontTypes.errorSmall:
        style = context.font.bodySmall!.copyWith(color: context.colour.error);
    }

    if (onSurface) style = style.copyWith(color: context.colour.onSurface);
    if (isBlue) style = style.copyWith(color: context.colour.secondary);
    if (isRed) style = style.copyWith(color: context.colour.primary);
    if (isGreen) style = style.copyWith(color: Colors.green);
    if (isBold) style = style.copyWith(fontWeight: FontWeight.bold);
    if (removeColourOpacity) style = style.copyWith(color: context.colour.onBackground);
    if (fontSize != null) style = style.copyWith(fontSize: fontSize);
    if (compact) style = style.copyWith(height: 0.8);

    return Text(
      text,
      style: style,
      key: uiKey,
      textAlign: textAlign,
    );
  }
}
