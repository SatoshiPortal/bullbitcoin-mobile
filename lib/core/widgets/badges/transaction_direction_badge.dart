import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class TransactionDirectionBadge extends StatelessWidget {
  const TransactionDirectionBadge({
    super.key,
    required this.isIncoming,
    this.isSwap = false,
  });

  final bool isIncoming;
  final bool isSwap;
  @override
  Widget build(BuildContext context) {
    final iconColor = isIncoming
        ? context.appColors.primary
        : context.appColors.textMuted;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(
        isSwap
            ? Icons.swap_vert_rounded
            : isIncoming
            ? Icons.south_west_rounded
            : Icons.north_east_rounded,
        color: iconColor,
        size: 24,
      ),
    );
  }
}
