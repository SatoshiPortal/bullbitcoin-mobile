import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/recoverbull_flow.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';
import 'password_input_page.dart';
import 'vault_provider_selection_page.dart';

/// Lets a recovery or a test skip the key server: the vault file and its key
/// are enough, so neither consent, Tor nor the server should stand in the way.
class VaultKeyInsteadButton extends StatelessWidget {
  /// Runs before leaving, so the screen stops reacting to the server.
  final VoidCallback? onLeave;

  const VaultKeyInsteadButton({super.key, this.onLeave});

  static bool offeredFor(RecoverBullFlow flow) =>
      flow == RecoverBullFlow.recoverVault || flow == RecoverBullFlow.testVault;

  @override
  Widget build(BuildContext context) {
    if (!offeredFor(RecoverBullFlowScope.of(context).flow)) {
      return const SizedBox.shrink();
    }
    return BullButton.big(
      label: context.loc.recoverbullEnterVaultKeyInstead,
      bgColor: context.bull.transparent,
      textColor: context.bull.info,
      textStyle: context.bullText.labelLarge,
      onPressed: () {
        onLeave?.call();
        final vault = context.read<VaultFlowCubit>().state.vault;
        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => vault != null
                  ? const PasswordInputPage(vaultKeyOnly: true)
                  : const VaultProviderSelectionPage(vaultKeyOnly: true),
            ),
          ),
        );
      },
    );
  }
}
