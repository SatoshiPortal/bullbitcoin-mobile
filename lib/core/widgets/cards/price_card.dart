import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class PriceCard extends StatelessWidget {
  const PriceCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return BBText(
      text,
      style: context.font.displayMedium,
      color: context.colour.onPrimary,
    );
  }
}
