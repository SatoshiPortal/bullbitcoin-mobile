import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class LogoutConfirmationBottomSheet extends StatelessWidget {
  final Future<void> Function() onConfirm;

  const LogoutConfirmationBottomSheet({super.key, required this.onConfirm});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onConfirm,
  }) {
    return BlurredBottomSheet.show(
      context: context,
      child: LogoutConfirmationBottomSheet(onConfirm: onConfirm),
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
            mainAxisSize: .min,
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
              Icon(Icons.logout, size: 48, color: context.appColors.primary),
              const SizedBox(height: 16),
              BBText(
                context.loc.logoutConfirmationTitle,
                style: context.font.headlineSmall?.copyWith(fontWeight: .bold),
                textAlign: .center,
              ),
              const SizedBox(height: 8),
              BBText(
                context.loc.logoutConfirmationDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: .center,
                maxLines: 4,
                overflow: .ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BBButton.small(
                      label: context.loc.logoutConfirmationCancel,
                      onPressed: () => Navigator.of(context).pop(),
                      outlined: true,
                      bgColor: Colors.transparent,
                      textColor: context.appColors.secondary,
                      borderColor: context.appColors.outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BBButton.small(
                      label: context.loc.logoutConfirmationLogout,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await onConfirm();
                      },
                      bgColor: context.appColors.secondary,
                      textColor: context.appColors.onSecondary,
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
