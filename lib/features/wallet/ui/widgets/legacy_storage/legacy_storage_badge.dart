import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class LegacyStorageBadge extends StatelessWidget {
  const LegacyStorageBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.primary,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Bebas Neue',
          color: context.appColors.onPrimary,
          fontSize: 14,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
