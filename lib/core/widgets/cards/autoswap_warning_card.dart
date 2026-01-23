import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AutoSwapWarningCard extends StatelessWidget {
  const AutoSwapWarningCard({
    super.key,
    required this.onTap,
    this.isActiveMode = false,
  });

  final Function onTap;
  final bool isActiveMode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap();
      },
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
            Icon(
              Icons.check_circle_outline,
              color: context.appColors.success,
              size: 24,
            ),
            const Gap(14),
            Expanded(
              child: isActiveMode
                  ? BBText(
                      context.loc.autoswapActiveCardTitle,
                      style: context.font.bodyMedium,
                      color: context.appColors.onSurface,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(
                          context.loc.autoswapWarningCardTitle,
                          style: context.font.bodyMedium,
                          color: context.appColors.onSurface,
                        ),
                        const Gap(2),
                        GestureDetector(
                          onTap: () {
                            onTap();
                          },
                          child: Text(
                            context.loc.autoswapWarningCardSubtitle,
                            style: context.font.bodySmall?.copyWith(
                              decoration: TextDecoration.underline,
                              color: context.appColors.onSurfaceVariant,
                            ),
                          ),
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
