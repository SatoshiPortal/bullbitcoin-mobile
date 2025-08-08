import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotLoggedInBottomSheet extends StatelessWidget {
  const NotLoggedInBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.onPrimary,
      useRootNavigator: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) => const NotLoggedInBottomSheet(),
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
              Icon(
                Icons.account_circle_outlined,
                size: 48,
                color: context.colour.primary,
              ),
              const SizedBox(height: 16),
              BBText(
                'You Are Not Logged in',
                style: context.font.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              BBText(
                'Please log in to your Bull Bitcoin account to access exchange settings.',
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              BBButton.big(
                label: 'LOGIN',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.goNamed(ExchangeRoute.exchangeHome.name);
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
