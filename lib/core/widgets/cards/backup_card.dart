import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, Gap, BullTypographyX;

class BackupCard extends StatelessWidget {
  const BackupCard({super.key, required this.onTap});

  final Function onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: () {
        onTap();
      },
      child: Container(
        // 15 + the 1px border = 16 of space around the content.
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colors.banner,
          border: Border.all(color: colors.bannerOutline),
          borderRadius: BorderRadius.circular(context.bullShapes.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              Assets.misc.passwordbook.path,
              height: 32,
              width: 32,
              color: colors.onBanner,
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BullText(
                    context.loc.backupCardTitle,
                    style: context.bullType.body,
                    color: colors.onBanner,
                  ),
                  BullText(
                    context.loc.backupCardSubtitle,
                    style: context.bullType.body,
                    color: colors.onBanner,
                  ),
                ],
              ),
            ),
            const Gap(8),
            Icon(Icons.arrow_forward, color: colors.onBanner),
          ],
        ),
      ),
    );
  }
}
