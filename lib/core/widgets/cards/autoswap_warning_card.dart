import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AutoSwapWarningCard extends StatelessWidget {
  const AutoSwapWarningCard({super.key, required this.onTap});

  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: context.appColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: context.appColors.success,
              size: 20,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    context.loc.autoswapWarningCardTitle,
                    style: context.font.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.text,
                  ),
                  Text(
                    'Tap to configure',
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.appColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
