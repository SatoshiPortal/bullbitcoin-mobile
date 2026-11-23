import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, BullThemeX, BullTypographyX, Gap;

import '../backups_copy.dart';

class HowToDecideBackupOption extends StatelessWidget {
  final BackupsCopy copy;

  const HowToDecideBackupOption({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.bull.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.bullShapes.sheet),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: BullText(
                        copy.helpTitle,
                        style: context.bullType.subtitle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: .center,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: copy.closeLabel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Gap(32),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BullText(
                        copy.losePhysical,
                        style: context.bullType.label.copyWith(height: 1.5),
                        maxLines: 8,
                      ),
                      const Gap(32),
                      BullText(
                        copy.encryptedVault,
                        style: context.bullType.label.copyWith(height: 1.5),
                        maxLines: 16,
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.bullType.body,
                          children: [
                            TextSpan(
                              text: copy.physicalRecommendation,
                              style: context.bullType.caption.copyWith(
                                fontWeight: .bold,
                              ),
                            ),
                            TextSpan(
                              text: copy.physicalRecommendationText,
                              style: context.bullType.caption,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.bullType.body,
                          children: [
                            TextSpan(
                              text: copy.encryptedRecommendation,
                              style: context.bullType.caption.copyWith(
                                fontWeight: .bold,
                              ),
                            ),
                            TextSpan(
                              text: copy.encryptedRecommendationText,
                              style: context.bullType.caption,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      BullText(
                        copy.moreInfo,
                        style: context.bullType.label.copyWith(height: 1.5),
                      ),
                      const Gap(20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
