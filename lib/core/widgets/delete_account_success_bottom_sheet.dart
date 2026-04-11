import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class DeleteAccountSuccessBottomSheet extends StatelessWidget {
  const DeleteAccountSuccessBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      isDismissible: false,
      child: const DeleteAccountSuccessBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: context.appColors.primary,
              ),
              const SizedBox(height: 16),
              BBText(
                context.loc.deleteAccountSuccessTitle,
                style: context.font.headlineSmall?.copyWith(fontWeight: .bold),
                textAlign: .center,
              ),
              const SizedBox(height: 8),
              BBText(
                context.loc.deleteAccountSuccessDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: .center,
                maxLines: 5,
                overflow: .ellipsis,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: BBButton.small(
                  label: context.loc.deleteAccountSuccessClose,
                  onPressed: () => Navigator.of(context).pop(),
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
