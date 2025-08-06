import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    this.title,
    required this.description,
    required this.tagColor,
    required this.bgColor,
    this.onTap,
  });

  final String? title;
  final String description;
  final Color tagColor;
  final Color bgColor;
  final Function? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap?.call(),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 4, height: 75, color: tagColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 24, color: tagColor),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null && title!.isNotEmpty) ...[
                            BBText(
                              title!,
                              style: context.font.bodyLarge,
                              color: tagColor,
                            ),
                            const Gap(4),
                          ],
                          Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: BBText(
                              description,
                              style: context.font.bodyMedium,
                              color: context.colour.secondary,
                              maxLines: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
