import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class BBText extends StatelessWidget {
  const BBText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final int maxLines;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      text,
      style: style,
      maxLines: maxLines,
    );
  }
}
