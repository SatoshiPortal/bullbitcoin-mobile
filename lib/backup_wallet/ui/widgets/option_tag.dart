import 'package:bb_mobile/_ui/components/text/text.dart' show BBText;
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class OptionsTag extends StatelessWidget {
  final String text;
  const OptionsTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: context.colour.surface,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colour.surface,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BBText(
        text,
        style: context.font.labelMedium,
      ),
    );
  }
}
