import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullIcon, BullShapesX, BullSizes, BullText, BullTextRole, Gap;

class BackupCard extends StatelessWidget {
  const BackupCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.banner,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            boxShadow: [
              BoxShadow(
                color: colors.scrim,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
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
                  mainAxisSize: .min,
                  children: [
                    BullText(
                      context.loc.backupCardTitle,
                      role: BullTextRole.body,
                      color: colors.onBanner,
                    ),
                    BullText(
                      context.loc.backupCardSubtitle,
                      role: BullTextRole.body,
                      color: colors.onBanner,
                    ),
                  ],
                ),
              ),
              const Gap(8),
              BullIcon(Icons.arrow_forward, color: colors.onBanner),
            ],
          ),
        ),
      ),
    );
  }
}
