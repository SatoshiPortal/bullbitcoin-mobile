import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class HiddenAmountIcon extends StatelessWidget {
  const HiddenAmountIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.visibility_off_outlined,
      size: size,
      color: color ?? context.appColors.textMuted,
    );
  }
}
