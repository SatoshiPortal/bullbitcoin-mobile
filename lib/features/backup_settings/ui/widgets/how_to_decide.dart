import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, BullTypographyX, Gap;

class HowToDecideBackupOption extends StatelessWidget {
  const HowToDecideBackupOption({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
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
                mainAxisAlignment: .spaceBetween,
                children: [
                  const Spacer(),
                  BullText(
                    context.loc.backupWalletHowToDecideBackupModalTitle,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: .center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: context.appColors.onSurface,
                    ),
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
                        context.loc.backupWalletHowToDecideBackupLosePhysical,
                        style: context.bullType.label.copyWith(height: 1.5),
                        maxLines: 8,
                      ),
                      const Gap(32),
                      BullText(
                        context.loc.backupWalletHowToDecideBackupEncryptedVault,
                        style: context.bullType.label.copyWith(height: 1.5),
                        maxLines: 16,
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.bullType.body,
                          children: [
                            TextSpan(
                              text: context
                                  .loc
                                  .backupWalletHowToDecideBackupPhysicalRecommendation,
                              style: context.bullType.caption.copyWith(
                                fontWeight: .bold,
                              ),
                            ),
                            TextSpan(
                              text: context
                                  .loc
                                  .backupWalletHowToDecideBackupPhysicalRecommendationText,
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
                              text: context
                                  .loc
                                  .backupWalletHowToDecideBackupEncryptedRecommendation,
                              style: context.bullType.caption.copyWith(
                                fontWeight: .bold,
                              ),
                            ),
                            TextSpan(
                              text: context
                                  .loc
                                  .backupWalletHowToDecideBackupEncryptedRecommendationText,
                              style: context.bullType.caption,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      BullText(
                        context.loc.backupWalletHowToDecideBackupMoreInfo,
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
