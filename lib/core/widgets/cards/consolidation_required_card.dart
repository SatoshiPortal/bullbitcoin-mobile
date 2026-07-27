import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ConsolidationRequiredCard extends StatelessWidget {
  const ConsolidationRequiredCard({
    super.key,
    this.onTap,
    required this.title,
    this.body,
  });

  final VoidCallback? onTap;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.surfaceContainer,
          border: Border.all(
            color: context.appColors.surfaceContainerHighest,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: context.appColors.error, size: 24),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    title,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                  ),
                  if (body != null) ...[
                    const Gap(2),
                    BBText(
                      body!,
                      style: context.font.bodyMedium,
                      color: context.appColors.secondary,
                      maxLines: 4,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
