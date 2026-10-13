import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';

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
  Widget build(BuildContext context) => BullStatusScreen(
    title: title,
    description: description,
    extras: extras,
    isLoading: isLoading,
    hasError: hasError,
    errorMessage: errorMessage,
    onTap: onTap,
    buttonText: buttonText,
    errorTitle: context.loc.oopsSomethingWentWrong,
    retryLabel: context.loc.statusScreenTryAgain,
    continueLabel: context.loc.statusScreenContinue,
  );
}
