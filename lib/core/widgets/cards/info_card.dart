import 'package:bb_mobile/core/themes/app_theme.dart';
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
    this.boldDescription = false,
  });

  final String? title;
  final String description;
  final Color tagColor;
  final Color bgColor;
  final Function? onTap;
  final bool boldDescription;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap?.call(),
      child: Container(
        clipBehavior: .hardEdge,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(2),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            mainAxisAlignment: .center,
            children: [
              Container(width: 4, color: tagColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: .start,
                    mainAxisAlignment: .center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 24,
                        color: tagColor,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: .center,
                          crossAxisAlignment: .start,
                          children: [
                            if (title != null && title!.isNotEmpty) ...[
                              Text(
                                title!,
                                style: context.font.bodyLarge?.copyWith(
                                  color: tagColor,
                                ),
                              ),
                              const Gap(4),
                            ],
                            Text(
                              description,
                              style: context.font.bodyMedium?.copyWith(
                                color: context.appColors.onSurfaceVariant,
                                fontWeight:
                                    boldDescription
                                        ? .bold
                                        : .normal,
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
      ),
    );
  }
}
