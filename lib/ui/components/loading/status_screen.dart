import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/ui/components/template/screen_template.dart';

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
    final textColor = widget.hasError ? context.colour.error : null;

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
                bgColor: context.colour.secondary,
              )
            : const SizedBox.shrink(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.hasError)
                  Icon(
                    Icons.error_outline_rounded,
                    size: 80,
                    color: textColor,
                  )
                else
                  const SizedBox.shrink(),
                ProgressScreen(
                  title: !widget.hasError
                      ? widget.title
                      : "Oops! Something went wrong",
                  description: !widget.hasError
                      ? widget.description
                      : widget.errorMessage,
                  isLoading: widget.isLoading && !widget.hasError,
                ),
                if (widget.extras.isNotEmpty && !widget.hasError) ...[
                  const Gap(16),
                  ...widget.extras,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
