import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class BBText extends StatelessWidget {
  const BBText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.color,
    this.textAlign,
  });

  final String text;
  final int maxLines;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      text,
      style: style!.copyWith(color: color),
      maxLines: maxLines,
      textAlign: textAlign,
      softWrap: true,
    );
  }
}
