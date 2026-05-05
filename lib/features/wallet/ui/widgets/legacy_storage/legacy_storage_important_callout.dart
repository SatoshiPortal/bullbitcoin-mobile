import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class LegacyStorageImportantCallout extends StatelessWidget {
  const LegacyStorageImportantCallout({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.errorContainer,
        border: Border(
          left: BorderSide(color: context.appColors.primary, width: 3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: context.appColors.primary,
            size: 20,
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  title,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                BBText(
                  body,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
