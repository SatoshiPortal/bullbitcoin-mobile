import 'package:bb_mobile/ui/components/bottom_sheet/x.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
                      'Warning: The backup key gives access to your Bitcoin. Anyone with this key can steal all your funds.',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 4,
                    ),
                    const Gap(24),
                    BBText(
                      'Never save the backup key on the same device or in the same location as your backup file. Store them separately and securely.',
                      maxLines: 4,
                      style: context.font.bodyMedium,
                    ),
                    const Gap(16),
                    BBText(
                      'Only download the backup key if you understand the security implications and have a secure storage plan.',
                      maxLines: 4,
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
