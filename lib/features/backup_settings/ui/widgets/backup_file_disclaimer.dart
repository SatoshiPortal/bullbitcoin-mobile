import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupFileDisclaimerBottomSheet extends StatelessWidget {
  const BackupFileDisclaimerBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return BlurredBottomSheet.show<bool?>(
      context: context,
      child: const BackupFileDisclaimerBottomSheet(),
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
                      '⚠️ Critical Warning',
                      style: context.font.headlineMedium?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
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
                      'Before downloading this backup file, you MUST understand:',
                      style: context.font.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                    ),
                    const Gap(16),
                    const _WarningPoint(
                      icon: '🔓',
                      text: 'Anyone who gets this file can steal your Bitcoin',
                    ),
                    const Gap(12),
                    const _WarningPoint(
                      icon: '📱',
                      text:
                          'Never store this file on the same device as this app',
                    ),
                    const Gap(12),
                    const _WarningPoint(
                      icon: '☁️',
                      text:
                          'Never upload to cloud storage (Google Drive, iCloud, etc.)',
                    ),
                    const Gap(12),
                    const _WarningPoint(
                      icon: '💻',
                      text: 'Never email or message this file to anyone',
                    ),
                    const Gap(12),
                    const _WarningPoint(
                      icon: '🔒',
                      text: 'Store only on secure, offline, encrypted storage',
                    ),
                    const Gap(24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colour.secondary.withValues(alpha: 0.1),
                        border: Border.all(color: context.colour.secondary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: BBText(
                        'Recommended: Use this only for advanced backup strategies if you fully understand the security implications.',
                        style: context.font.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 4,
                      ),
                    ),
                    const Gap(32),
                    Row(
                      children: [
                        Expanded(
                          child: BBButton.big(
                            label: 'Cancel',
                            onPressed: () => context.pop(false),
                            bgColor: Colors.transparent,
                            outlined: true,
                            textColor: context.colour.secondary,
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: BBButton.big(
                            label: 'Continue',
                            onPressed: () => context.pop(true),
                            bgColor: context.colour.secondary,
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

class _WarningPoint extends StatelessWidget {
  final String icon;
  final String text;

  const _WarningPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const Gap(12),
        Expanded(
          child: BBText(text, style: context.font.bodyMedium, maxLines: 3),
        ),
      ],
    );
  }
}
