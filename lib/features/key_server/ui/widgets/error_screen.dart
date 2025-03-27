import 'package:bb_mobile/features/key_server/ui/key_server_flow.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    super.key,
    required this.message,
    required this.title,
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.onSecondary,
      body: PageLayout(
        bottomChild: BBButton.big(
          label: 'Try again!',
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
          onPressed: () => context.go(AppRoute.home.path),
        ),
        children: [
          const Gap(150),
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 50,
            color: context.colour.error,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
