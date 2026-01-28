import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class RemoveConnectionDialog extends StatelessWidget {
  const RemoveConnectionDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return BlurredBottomSheet.show<bool>(
      context: context,
      child: const RemoveConnectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(
                'Remove Connection',
                style: context.font.headlineSmall?.copyWith(
                  color: context.appColors.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              BBText(
                'Are you sure you want to remove this Bitaxe device connection? You will need to reconnect to access the device again.',
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              Row(
                children: [
                  Expanded(
                    child: BBButton.small(
                      label: 'Cancel',
                      onPressed: () => context.pop(false),
                      bgColor: context.appColors.transparent,
                      outlined: true,
                      textColor: context.appColors.text,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: BBButton.small(
                      label: 'Remove',
                      onPressed: () => context.pop(true),
                      bgColor: context.appColors.error,
                      textColor: context.appColors.onError,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
