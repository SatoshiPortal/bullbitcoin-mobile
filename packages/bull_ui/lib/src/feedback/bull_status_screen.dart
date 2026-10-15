import 'package:flutter/material.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../chrome/bull_scaffold.dart';
import '../layout/bull_stacked_page.dart';
import '../buttons/bull_button.dart';
import 'bull_progress_screen.dart';

/// Root's loading/success/error state machine, using BullButton for actions.
class BullStatusScreen extends StatelessWidget {
  final String errorTitle;
  final String retryLabel;
  final String continueLabel;
  final String? title;
  final String? description;
  final List<Widget> extras;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onTap;
  final String? buttonText;

  const BullStatusScreen({
    super.key,
    required this.errorTitle,
    required this.retryLabel,
    required this.continueLabel,
    this.title,
    this.description,
    this.extras = const [],
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.onTap,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    final showAction = !isLoading && onTap != null;
    return BullScaffold(
      body: BullStackedPage(
        bottomChild: showAction
            ? BullButton.big(
                label: buttonText ?? (hasError ? retryLabel : continueLabel),
                onPressed: onTap!,
                textColor: context.bull.onSecondary,
                bgColor: context.bull.secondary,
              )
            : const SizedBox.shrink(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xl),
              child: Column(
                children: [
                  if (hasError)
                    Icon(
                      Icons.error_outline_rounded,
                      size: 80,
                      color: context.bull.error,
                    ),
                  BullProgressScreen(
                    title: hasError ? errorTitle : title,
                    description: hasError ? errorMessage : description,
                    isLoading: isLoading && !hasError,
                  ),
                  if (extras.isNotEmpty && !hasError) ...[
                    const SizedBox(height: BullSpacing.md),
                    ...extras,
                  ],
                  const SizedBox(height: BullSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
