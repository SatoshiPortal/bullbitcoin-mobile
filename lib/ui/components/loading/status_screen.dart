import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/ui/components/template/screen_template.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A screen that handles three states: loading, success, and error
/// Automatically pops on error after specified duration if autoPop is true
class StatusScreen extends StatefulWidget {
  final String? title;
  final String? description;
  final List<Widget> extras;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onTap;
  final String? buttonText;
  final bool autoPop;
  final Duration errorPopDelay;

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
    this.autoPop = true,
    this.errorPopDelay = const Duration(seconds: 3),
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.hasError && widget.autoPop) {
      Future.delayed(widget.errorPopDelay, () {
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.onSecondary,
      body: StackedPage(
        bottomChildHeight: MediaQuery.of(context).size.height * 0.2,
        bottomChild: (!widget.isLoading && widget.onTap != null)
            ? BBButton.big(
                label: widget.hasError
                    ? (widget.buttonText ?? 'Try Again')
                    : (widget.buttonText ?? 'Continue'),
                onPressed: widget.onTap ?? () {},
                textColor: context.colour.onPrimary,
                bgColor: widget.hasError
                    ? context.colour.error
                    : context.colour.secondary,
              )
            : const SizedBox.shrink(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                ProgressScreen(
                  isLoading: true,
                  title: widget.title,
                  description: widget.description,
                )
              else ...[
                if (widget.hasError)
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: context.colour.error,
                  ),
                if (widget.title != null) ...[
                  const Gap(16),
                  BBText(
                    widget.hasError
                        ? (widget.errorMessage ?? 'An error occurred')
                        : widget.title!,
                    textAlign: TextAlign.center,
                    style: context.font.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.hasError ? context.colour.error : null,
                    ),
                  ),
                ],
                if (widget.description != null) ...[
                  const Gap(16),
                  BBText(
                    widget.description!,
                    textAlign: TextAlign.center,
                    style: context.font.bodySmall?.copyWith(
                      color: widget.hasError ? context.colour.error : null,
                    ),
                    maxLines: 3,
                  ),
                ],
                if (widget.extras.isNotEmpty) ...[
                  const Gap(16),
                  ...widget.extras,
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
