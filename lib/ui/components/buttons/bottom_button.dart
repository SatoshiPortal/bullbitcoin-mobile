import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BottomButton extends StatelessWidget {
  const BottomButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.selected,
  });

  final String icon;
  final String label;
  final void Function()? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colour.primary : context.colour.outline;

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Column(
          children: [
            Image.asset(icon, width: 24, height: 24, color: color),
            const SizedBox(height: 8),
            BBText(label, style: context.font.labelLarge, color: color),
          ],
        ),
      ),
    );
  }
}
