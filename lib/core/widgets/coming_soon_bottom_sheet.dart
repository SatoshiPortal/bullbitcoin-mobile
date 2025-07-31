import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';

class ComingSoonBottomSheet extends StatelessWidget {
  final String description;
  final String? icon;
  final void Function()? onDismissed;

  const ComingSoonBottomSheet({
    super.key,
    this.description =
        'This feature is currently under development and will be available soon.',
    this.icon,
    this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    String? description,
    String? icon,
    void Function()? onDismissed,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.onPrimary,
      useRootNavigator: true,
      builder:
          (context) => ComingSoonBottomSheet(
            description:
                description ??
                'This feature is currently under development and will be available soon.',
            icon: icon,
            onDismissed: onDismissed,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              if (icon != null) ...[
                Icon(
                  Icons.construction,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Feature Coming Soon',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              BBButton.big(
                label: 'OK',
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismissed?.call();
                },
                bgColor: theme.colorScheme.secondary,
                textColor: theme.colorScheme.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
