import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/template/screen_template.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A screen that handles three states: loading, success, and error

class StatusScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget> extras;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onTap;
  final String? buttonText;

  const StatusScreen({
    super.key,
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
    final textColor = hasError ? context.colour.error : null;

    return Scaffold(
      backgroundColor: context.colour.onSecondary,
      body: StackedPage(
        bottomChild:
            (!isLoading && onTap != null)
                ? BBButton.big(
                  label:
                      hasError
                          ? (buttonText ?? 'Try Again')
                          : (buttonText ?? 'Continue'),
                  onPressed: onTap ?? () {},
                  textColor: context.colour.onPrimary,
                  bgColor: context.colour.secondary,
                )
                : const SizedBox.shrink(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasError)
                  Icon(Icons.error_outline_rounded, size: 80, color: textColor)
                else
                  const SizedBox.shrink(),
                ProgressScreen(
                  title: !hasError ? title : "Oops! Something went wrong",
                  description: !hasError ? description : errorMessage,
                  isLoading: isLoading && !hasError,
                ),
                if (extras.isNotEmpty && !hasError) ...[
                  const Gap(16),
                  ...extras,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
