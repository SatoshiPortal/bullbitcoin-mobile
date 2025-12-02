import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class HowToDecideBackupOption extends StatelessWidget {
  const HowToDecideBackupOption({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(),
                  BBText(
                    context.loc.backupWalletHowToDecideBackupModalTitle,
                    style: context.font.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: context.colorScheme.secondary,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        context.loc.backupWalletHowToDecideBackupLosePhysical,
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                        maxLines: 8,
                      ),
                      const Gap(32),
                      BBText(
                        context.loc.backupWalletHowToDecideBackupEncryptedVault,
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                        maxLines: 16,
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.font.bodyMedium,
                          children: [
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideBackupPhysicalRecommendation,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideBackupPhysicalRecommendationText,
                              style: context.font.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.font.bodyMedium,
                          children: [
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideBackupEncryptedRecommendation,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideBackupEncryptedRecommendationText,
                              style: context.font.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      BBText(
                        context.loc.backupWalletHowToDecideBackupMoreInfo,
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
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
