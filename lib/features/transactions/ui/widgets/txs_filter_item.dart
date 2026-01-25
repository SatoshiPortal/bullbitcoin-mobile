import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TxsFilterItem extends StatelessWidget {
  const TxsFilterItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appColors.primary
              : context.appColors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? context.appColors.primary
                : context.appColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: context.font.bodySmall?.copyWith(
                color: isSelected
                    ? context.appColors.background
                    : context.appColors.text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count != null) ...[
              const Gap(6),
              Text(
                '$count',
                style: context.font.labelSmall?.copyWith(
                  color: isSelected
                      ? context.appColors.background.withValues(alpha: 0.7)
                      : context.appColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
