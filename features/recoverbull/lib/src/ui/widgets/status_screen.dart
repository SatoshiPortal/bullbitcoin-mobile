import 'package:bull_ui/bull_ui.dart';
import '../../l10n/context_localizations.dart';
import 'progress_screen.dart';

/// Root's loading/success/error state machine, using BullButton for actions.
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
    final showAction = !isLoading && onTap != null;
    return BullScaffold(
      body: _StackedPage(
        bottomChild: showAction
            ? BullButton.big(
                label:
                    buttonText ??
                    (hasError
                        ? context.loc.statusScreenTryAgain
                        : context.loc.statusScreenContinue),
                onPressed: onTap!,
                textColor: context.bull.onSecondary,
                bgColor: context.bull.secondary,
              )
            : const SizedBox.shrink(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  if (hasError)
                    Icon(
                      Icons.error_outline_rounded,
                      size: 80,
                      color: context.bull.error,
                    ),
                  ProgressScreen(
                    title: hasError
                        ? context.loc.oopsSomethingWentWrong
                        : title,
                    description: hasError ? errorMessage : description,
                    isLoading: isLoading && !hasError,
                  ),
                  if (extras.isNotEmpty && !hasError) ...[
                    const SizedBox(height: BullSpacing.md),
                    ...extras,
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StackedPage extends StatelessWidget {
  final Widget child;
  final Widget bottomChild;

  const _StackedPage({required this.child, required this.bottomChild});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.only(
            bottom: 32,
            top: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.bull.onSecondary.withValues(alpha: 0),
                context.bull.onSecondary,
              ],
              stops: const [0.0, 0.3],
            ),
          ),
          child: bottomChild,
        ),
      ),
    ],
  );
}
