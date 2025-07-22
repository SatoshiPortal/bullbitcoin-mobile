import 'package:bb_mobile/core/themes/app_theme.dart';
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
          color: context.colour.onPrimary,
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
                    "How to decide",
                    style: context.font.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: context.colour.secondary),
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
                        "One of the most common ways people lose their Bitcoin is because they lose the physical backup. "
                        "Anybody that finds your physical backup will be able to take all your Bitcoin. "
                        "If you are very confident that you can hide it well and never lose it, it's a good option.",
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                        maxLines: 8,
                      ),
                      const Gap(32),
                      BBText(
                        "The encrypted vault prevents you from thieves looking to steal your backup. "
                        "It also prevents you from accidentally losing your backup since it will be stored in your cloud. "
                        "Cloud storage providers like Google or Apple won't have access to your Bitcoin because the encryption password is too strong. "
                        "There is a small possibility that the web server that stores your backup's encryption key could be compromised. "
                        "In this event, the security of the backup in your cloud account could be at risk.",
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
                              text: 'Physical backup: ',
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'You are confident in your own operational security capabilities to hide and preserve your Bitcoin seed words.',
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
                              text: 'Encrypted vault: ',
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'You are not sure and you need more time to learn about backup security practices.',
                              style: context.font.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      BBText(
                        'Visit recoverbull.com for more information.',
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

class HowToDecideVaultLocation extends StatelessWidget {
  const HowToDecideVaultLocation({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
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
                    "How to decide",
                    style: context.font.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: context.colour.secondary),
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
                        "Cloud storage providers like Google or Apple won't have access to your Bitcoin because the encryption password is too strong. They can only access your Bitcoin in the unlikely event they collude with the key server (the online service which stores your encryption password). If the key server ever gets hacked, your Bitcoin could be at risk with Google or Apple cloud.",
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                        maxLines: 16,
                      ),
                      const Gap(32),
                      BBText(
                        'A custom location can be much more secure, depending on which location you choose. You must also make sure not to lose the backup file or to lose the device on which your backup file is stored.',
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
                              text: 'Custom location: ',
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'you are confident you will not lose the vault file and it will still be accessible if you lose your phone.',
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
                              text: 'Google or Apple cloud: ',
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'you want to make sure you never lose access to your vault file even if you lose your devices.',
                              style: context.font.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      BBText(
                        'Visit recoverbull.com for more information.',
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
