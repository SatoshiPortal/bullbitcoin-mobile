import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class HowToDecideSheetBackupOption extends StatelessWidget {
  const HowToDecideSheetBackupOption({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar (Title & Close Button)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
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
            const Gap(12),

            // Content (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText(
                      style: context.font.labelMedium?.copyWith(height: 1.5),
                      "One of the most common ways people lose their Bitcoin is because they lose the physical backup. "
                      "Anybody that finds your physical backup will be able to take all your Bitcoin. "
                      "If you are very confident that you can hide it well and never lose it, it’s a good option.",
                      maxLines: 8,
                    ),
                    const Gap(12),
                    BBText(
                      style: context.font.labelMedium?.copyWith(height: 1.5),
                      "The encrypted vault prevents you from thieves looking to steal your backup. "
                      "It also prevents you from accidentally losing your backup since it will be stored in your cloud. "
                      "Cloud storage providers like Google or Apple won’t have access to your Bitcoin because the encryption password is too strong. "
                      "There is a small possibility that the web server that stores your backup’s encryption key could be compromised. "
                      "In this event, the security of the backup in your cloud account could be at risk.",
                      maxLines: 16,
                    ),
                    const Gap(12),
                    BBText(
                      style: context.font.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w900, fontSize: 13),
                      "Physical backup:",
                    ),
                    BBText(
                      "You are confident in your own operational security capabilities to hide and preserve your Bitcoin seed words.",
                      style: context.font.labelMedium,
                    ),
                    const Gap(12),
                    BBText(
                      style: context.font.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w900, fontSize: 13),
                      "Encrypted vault:",
                    ),
                    BBText(
                      "You are not sure and you need more time to learn about backup security practices.",
                      style: context.font.labelMedium,
                    ),
                    const Gap(12),
                    BBText(
                      "Visit recoverbull.com for more information",
                      style: context.font.labelMedium,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Drag Handle
            Center(
              child: Container(
                width: 120,
                height: 5,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: context.colour.secondary,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
