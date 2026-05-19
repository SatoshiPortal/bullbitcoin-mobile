import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/backup_success_screen.dart';
import 'package:flutter/material.dart';

class TestCompletedPage extends StatelessWidget {
  const TestCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackupSuccessScreen(
      title: context.loc.recoverbullTestCompletedTitle,
      message: context.loc.recoverbullTestSuccessDescription,
      buttonLabel: context.loc.recoverbullGotIt,
    );
  }
}
