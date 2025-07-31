import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupKeyWarningBottomSheet extends StatelessWidget {
  const BackupKeyWarningBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return BlurredBottomSheet.show<bool?>(
      context: context,
      child: const BackupKeyWarningBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                const Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Gap(24),
                    BBText(
                      'Security Warning',
                      style: context.font.headlineMedium,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText(
                      'Warning: Be careful where you save the backup key.',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 4,
                    ),
                    const Gap(24),
                    BBText(
                      'It is critically important that you do not save the backup key at the same place where you save your backup file. Always store them on separate devices or separate cloud providers.',
                      maxLines: 4,
                      style: context.font.bodyMedium,
                    ),
                    const Gap(16),
                    BBText(
                      'For example, if you used Google Drive for your backup file, do not use Google Drive for your backup key.',
                      maxLines: 3,
                      style: context.font.bodyMedium,
                    ),
                    const Gap(32),
                    Row(
                      children: [
                        Expanded(
                          child: BBButton.big(
                            label: 'Cancel',
                            onPressed: () => Navigator.of(context).pop(false),
                            bgColor: Colors.transparent,
                            outlined: true,
                            textStyle: context.font.headlineLarge,
                            textColor: context.colour.secondary,
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: BBButton.big(
                            label: 'Continue',
                            onPressed: () => context.pop(true),
                            bgColor: context.colour.secondary,
                            textStyle: context.font.headlineLarge,
                            textColor: context.colour.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
