import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart' show BBText;
import 'package:flutter/material.dart';

class OptionsTag extends StatelessWidget {
  final String text;
  const OptionsTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        border: Border.all(color: context.colour.surface),
        boxShadow: [
          BoxShadow(color: context.colour.surface, offset: const Offset(0, 2)),
        ],
      ),
      child: BBText(text, style: context.font.labelMedium),
    );
  }
}
