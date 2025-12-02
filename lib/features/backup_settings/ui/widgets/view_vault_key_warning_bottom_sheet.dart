import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewVaultKeyWarningBottomSheet extends StatelessWidget {
  const ViewVaultKeyWarningBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return BlurredBottomSheet.show<bool?>(
      context: context,
      child: const ViewVaultKeyWarningBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.onPrimary,
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
                      context.loc.backupSettingsSecurityWarning,
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
                      context.loc.backupSettingsKeyWarningBold,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 4,
                    ),
                    const Gap(24),
                    BBText(
                      context.loc.backupSettingsKeyWarningMessage,
                      maxLines: 4,
                      style: context.font.bodyMedium,
                    ),
                    const Gap(16),
                    BBText(
                      context.loc.backupSettingsKeyWarningExample,
                      maxLines: 3,
                      style: context.font.bodyMedium,
                    ),
                    const Gap(32),
                    Row(
                      children: [
                        Expanded(
                          child: BBButton.big(
                            label: context.loc.cancelButton,
                            onPressed: () => Navigator.of(context).pop(false),
                            bgColor: Colors.transparent,
                            outlined: true,
                            textStyle: context.font.headlineLarge,
                            textColor: context.colorScheme.secondary,
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: BBButton.big(
                            label: context.loc.sendContinue,
                            onPressed: () => context.pop(true),
                            bgColor: context.colorScheme.secondary,
                            textStyle: context.font.headlineLarge,
                            textColor: context.colorScheme.onPrimary,
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
