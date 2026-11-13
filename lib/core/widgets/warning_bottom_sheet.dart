import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullBottomSheet, BullButton, BullShapesX, BullText, BullSpacing, Gap;
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
    return BullBottomSheet.show(
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.bullShapes.sheet),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BullText(
                  title,
                  style: context.font.headlineMedium,
                  color: context.appColors.onSurface,
                ),
                const Gap(BullSpacing.md),
                BullText(
                  message,
                  style: context.font.bodyMedium,
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.center,
                ),
                const Gap(BullSpacing.md),
                BullButton.big(
                  maxLines: null,
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
      ),
    );
  }
}
