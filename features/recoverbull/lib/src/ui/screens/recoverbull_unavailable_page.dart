import 'package:flutter/material.dart';

import '../../l10n/context_localizations.dart';
import '../widgets/status_screen.dart';

/// Shown in place of every RecoverBull flow when the feature could not be
/// composed at startup.
class RecoverBullUnavailablePage extends StatelessWidget {
  const RecoverBullUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) => StatusScreen(
    isLoading: false,
    hasError: true,
    buttonText: context.loc.recoverbullGotIt,
    onTap: () => Navigator.of(context).maybePop(),
  );
}
