import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WarningBottomSheet extends StatelessWidget {
  const WarningBottomSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    return BlurredBottomSheet.show(
      context: context,
      child: WarningBottomSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        onConfirm: onConfirm,
      ),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(
                title,
                style: context.font.headlineMedium,
                color: context.appColors.onSurface,
              ),
              const Gap(16),
              BBText(
                message,
                style: context.font.bodyMedium,
                color: context.appColors.onSurface,
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              BBButton.big(
                label: confirmLabel,
                onPressed: () {
                  onConfirm();
                  context.pop();
                },
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
