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
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.secondary,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(
              Icons.swap_horiz,
              color: context.appColors.onSecondary,
              size: 32,
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    context.loc.autoswapWarningCardTitle,
                    style: context.font.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    color: context.appColors.onSecondary,
                  ),
                  const Gap(4),
                  BBText(
                    context.loc.autoswapWarningCardSubtitle,
                    style: context.font.bodySmall,
                    color: context.appColors.onSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
