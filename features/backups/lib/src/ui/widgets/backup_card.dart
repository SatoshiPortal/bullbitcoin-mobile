import 'package:bull_ui/app_theme.dart';
import 'package:backups/src/backups_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullIcon, BullShapesX, BullText, BullTextRole, Gap;

class BackupCard extends StatelessWidget {
  const BackupCard({super.key, required this.icon, required this.onTap});

  final ImageProvider icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image(image: icon, height: 32, width: 32, color: colors.onBanner),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
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
