import 'package:bull_ui/bull_ui.dart';

import '../../l10n/context_localizations.dart';

/// Shown in place of every RecoverBull flow when the feature could not be
/// composed at startup.
class RecoverBullUnavailablePage extends StatelessWidget {
  const RecoverBullUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) => BullStatusScreen(
    errorTitle: context.recoverBullLabels.oopsSomethingWentWrong,
    retryLabel: context.recoverBullLabels.statusScreenTryAgain,
    continueLabel: context.recoverBullLabels.statusScreenContinue,
    isLoading: false,
    hasError: true,
    buttonText: context.loc.recoverbullGotIt,
    onTap: () => Navigator.of(context).maybePop(),
  );
}
