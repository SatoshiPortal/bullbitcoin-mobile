import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class LogoutConfirmationBottomSheet extends StatelessWidget {
  final VoidCallback onConfirm;

  const LogoutConfirmationBottomSheet({super.key, required this.onConfirm});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.onPrimary,
      useRootNavigator: true,
      builder: (context) => LogoutConfirmationBottomSheet(onConfirm: onConfirm),
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
                  color: context.colour.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.logout, size: 48, color: context.colour.error),
              const SizedBox(height: 16),
              BBText(
                'Confirm Logout',
                style: context.font.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              BBText(
                'Are you sure you want to log out of your Bull Bitcoin account? You will need to log in again to access exchange features.',
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BBButton.small(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                      bgColor: context.colour.secondaryFixed,
                      textColor: context.colour.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BBButton.small(
                      label: 'Logout',
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm();
                      },
                      bgColor: context.colour.error,
                      textColor: context.colour.onPrimary,
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
