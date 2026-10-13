import 'package:bull_ui/bull_ui.dart';
import '../../router/recoverbull_router.dart';
import '../../router/flow_type.dart';
import '../../l10n/context_localizations.dart';
import 'package:go_router/go_router.dart';

class VaultCreatedPage extends StatelessWidget {
  const VaultCreatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BullBackupSuccessScreen(
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
