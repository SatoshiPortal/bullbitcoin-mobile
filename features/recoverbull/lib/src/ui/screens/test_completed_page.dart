import 'package:flutter/material.dart';
import 'package:bull_recoverbull/src/l10n/context_localizations.dart';
import 'package:bull_recoverbull/src/ui/support.dart';
import 'package:go_router/go_router.dart';

class TestCompletedPage extends StatelessWidget {
  const TestCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackupSuccessScreen(
      title: context.loc.recoverbullTestCompletedTitle,
      message: context.loc.recoverbullTestSuccessDescription,
      buttonLabel: context.loc.recoverbullGotIt,
      onTap: () => context.go('/wallet'),
    );
  }
}
