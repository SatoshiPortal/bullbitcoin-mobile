import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class BackupCard extends StatelessWidget {
  const BackupCard({super.key, required this.onTap});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              Assets.misc.passwordbook.path,
              height: 32,
              width: 32,
              color: context.appColors.onSecondary,
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BBText(
                    context.loc.backupCardTitle,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSecondary,
                  ),
                  BBText(
                    context.loc.backupCardSubtitle,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSecondary,
                  ),
                ],
              ),
            ),
            const Gap(8),
            Icon(Icons.arrow_forward, color: context.appColors.onSecondary),
          ],
        ),
      ),
    );
  }
}
