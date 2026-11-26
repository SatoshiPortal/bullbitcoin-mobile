import 'package:bull_ui/app_theme.dart';
import 'package:backups/src/backups_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullIcon, BullShapesX, BullSizes, BullText, BullTextRole, Gap;

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
          constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.inverseSurface,
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
              Image(image: icon, height: 32, width: 32, color: colors.surface),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  children: [
                    BullText(
                      context.loc.backupCardTitle,
                      role: BullTextRole.body,
                      color: colors.surface,
                    ),
                    BullText(
                      context.loc.backupCardSubtitle,
                      role: BullTextRole.body,
                      color: colors.surface,
                    ),
                  ],
                ),
              ),
              const Gap(8),
              BullIcon(Icons.arrow_forward, color: colors.surface),
            ],
          ),
        ),
      ),
    );
  }
}
