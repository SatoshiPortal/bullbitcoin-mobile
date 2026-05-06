import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class WizardDots extends StatelessWidget {
  const WizardDots({
    super.key,
    required this.count,
    required this.index,
    this.activeColor,
    this.inactiveColor,
  });

  final int count;
  final int index;
  final Color? activeColor;

  /// Border color for inactive dots. Their fill is always
  /// [Colors.transparent] so the page bg (red splash, theme bg, etc.)
  /// shows through. Pass `null` to default to a muted ring.
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? context.appColors.primary;
    final inactiveBorder =
        inactiveColor ?? context.appColors.textMuted.withValues(alpha: 0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? active : Colors.transparent,
            border: isActive ? null : Border.all(color: inactiveBorder),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
