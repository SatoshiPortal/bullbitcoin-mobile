import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart' show BBText;
import 'package:flutter/material.dart';

class OptionsTag extends StatelessWidget {
  final String text;
  const OptionsTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border.all(color: context.appColors.border),
        boxShadow: [
          BoxShadow(
            color: context.appColors.border,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BBText(text, style: context.font.labelMedium),
    );
  }
}
