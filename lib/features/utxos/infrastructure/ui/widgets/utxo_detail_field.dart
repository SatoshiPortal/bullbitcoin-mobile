import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class UtxoDetailField extends StatelessWidget {
  const UtxoDetailField({
    super.key,
    required this.title,
    required this.value,
    this.valueStyle,
  });

  final String title;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 4.0),
        Text(value, style: valueStyle ?? context.theme.textTheme.bodyMedium),
      ],
    );
  }
}
