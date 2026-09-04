import '../../router/recoverbull_router.dart';
import '../../router/flow_type.dart';
import 'package:flutter/material.dart';
import '../../l10n/context_localizations.dart';
import '../support.dart';
import 'package:go_router/go_router.dart';

class VaultCreatedPage extends StatelessWidget {
  const VaultCreatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackupSuccessScreen(
      title: context.loc.recoverbullEncryptedVaultCreated,
      message: context.loc.recoverbullTestBackupDescription,
      buttonLabel: context.loc.recoverbullTestRecovery,
      onTap: () => context.pushNamed(
        RecoverBullRoute.recoverbullFlows.name,
        extra: RecoverBullFlowsExtra(
          flow: RecoverBullFlow.testVault,
          vault: null,
        ),
      ),
    );
  }
}
