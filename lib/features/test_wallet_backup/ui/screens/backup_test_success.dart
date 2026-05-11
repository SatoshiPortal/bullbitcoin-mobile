import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/backup_success_screen.dart';
import 'package:flutter/material.dart';

class BackupTestSuccessScreen extends StatelessWidget {
  const BackupTestSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackupSuccessScreen(
      title: context.loc.testBackupSuccessTitle,
      message: context.loc.testBackupSuccessMessage,
      buttonLabel: context.loc.testBackupSuccessButton,
    );
  }
}
