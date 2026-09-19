import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result_view.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VaultRecoveryScreen extends StatelessWidget {
  final VoidCallback onDescriptor;
  final VoidCallback onWords;
  final void Function(VaultBackupRecovery) onRecovered;
  const VaultRecoveryScreen({
    super.key,
    required this.onDescriptor,
    required this.onWords,
    required this.onRecovered,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultRecoverEntry)),
    body: SafeArea(
      child: BlocConsumer<VaultRecoveryCubit, VaultRecoveryState>(
        listener: (_, state) {
          if (state.result case final result?
              when result.complete &&
                  result.wallets.walletReferences.isNotEmpty) {
            onRecovered(result);
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(context.loc.vaultRecoveryDescription),
            const SizedBox(height: 16),
            if (state.busy) ...[
              const LinearProgressIndicator(),
              Text(context.loc.vaultBackupChecking),
            ],
            if (state.failure case final failure?)
              Text(
                failure is BackupSettingsWordsUnavailableFailure
                    ? context.loc.vaultRecoveryNoCredential
                    : failure.toTranslated(context),
              ),
            if (state.result case final result?)
              VaultRecoveryResultView(result: result),
            if (!state.busy)
              TextButton(
                onPressed: () => context.read<VaultRecoveryCubit>().search(),
                child: Text(context.loc.retry),
              ),
            const SizedBox(height: 24),
            Text(
              context.loc.vaultRecoveryManualTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SettingsEntryItem(
              icon: Icons.qr_code_scanner,
              title: context.loc.vaultRecoveryDescriptorEntry,
              onTap: onDescriptor,
            ),
            Text(context.loc.vaultRecoveryDescriptorHelp),
            SettingsEntryItem(
              icon: Icons.password_outlined,
              title: context.loc.dataBackupRecoverWithWords,
              onTap: onWords,
            ),
            Text(context.loc.vaultRecoveryWordsHelp),
          ],
        ),
      ),
    ),
  );
}
