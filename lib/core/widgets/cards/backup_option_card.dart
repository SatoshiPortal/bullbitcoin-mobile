import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/tag_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BackupOptionCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;
  final String? tag;
  final VoidCallback onTap;

  const BackupOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: context.colour.surface),
          boxShadow: [
            BoxShadow(
              color: context.colour.surface,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 36, height: 45, child: icon),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(title, style: context.font.headlineMedium),
                        const Gap(10),
                        BBText(
                          description,
                          style: context.font.bodySmall?.copyWith(
                            color: context.colour.outline,
                          ),
                          maxLines: 3,
                        ),
                        const Gap(10),
                        if (tag != null) OptionsTag(text: tag!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.arrow_forward, color: context.colour.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
