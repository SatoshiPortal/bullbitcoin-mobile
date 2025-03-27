import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.description,
    required this.tagColor,
    required this.bgColor,
  });

  final String title;
  final String description;
  final Color tagColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 100,
            color: tagColor,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 24,
                  color: tagColor,
                ),
                const Gap(12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText(
                      title,
                      style: context.font.bodyLarge,
                      color: context.colour.secondary,
                    ),
                    const Gap(4),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
