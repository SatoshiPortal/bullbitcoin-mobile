import 'package:flutter/material.dart';
import '../../l10n/context_localizations.dart';
import '../support.dart';
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
