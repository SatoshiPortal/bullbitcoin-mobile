import 'package:bull_ui/bull_ui.dart';

import '../../domain/entities/vault_completion.dart';
import '../../domain/entities/vault_recovery.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../recoverbull_flow_navigator.dart';
import '../widgets/recoverbull_widgets.dart';

List<Widget> _notices(BuildContext context, VaultCompletion completion) => [
  if (completion.recovery case VaultRecoveryNeedsWallets(:final failure))
    _Notice(failure.toTranslated(context)),
  if (completion.warning case final warning?)
    _Notice(warning.toTranslated(context)),
];

class _Notice extends StatelessWidget {
  final String message;

  const _Notice(this.message);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: BullInfoCard(
      description: message,
      tagColor: context.bull.warning,
      bgColor: context.bull.warningContainer,
    ),
  );
}

/// A new vault is sealed and saved; the next step is to test it.
class VaultCreatedPage extends StatelessWidget {
  final VaultCompletion completion;

  const VaultCreatedPage({super.key, required this.completion});

  @override
  Widget build(BuildContext context) {
    return RecoverBullStatusScreen(
      title: context.loc.recoverbullEncryptedVaultCreated,
      description: context.loc.recoverbullTestBackupDescription,
      buttonText: context.loc.recoverbullTestRecovery,
      onTap: RecoverBullFlowScope.of(context).onTestVault,
      extras: _notices(context, completion),
    );
  }
}

/// A test, or a recovery that still needs attention, finished.
class VaultVerifiedPage extends StatelessWidget {
  final VaultCompletion completion;

  const VaultVerifiedPage({super.key, required this.completion});

  @override
  Widget build(BuildContext context) {
    final scope = RecoverBullFlowScope.of(context);
    final recovered = completion.recovery != null;
    return RecoverBullSuccessScreen(
      title: recovered
          ? context.loc.recoverbullVaultImportedSuccess
          : context.loc.recoverbullTestCompletedTitle,
      message: recovered ? '' : context.loc.recoverbullTestSuccessDescription,
      buttonLabel: context.loc.recoverbullGotIt,
      onPressed: () => recovered
          ? (scope.onRecovered ?? scope.onFinished)()
          : scope.onFinished(),
      extras: _notices(context, completion),
    );
  }
}
