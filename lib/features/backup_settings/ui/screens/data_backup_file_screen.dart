import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_recovery_result.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_file_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataBackupFileScreen extends StatelessWidget {
  final void Function(WalletBackupSnapshot, WalletBackupRecovery) onRecovered;
  const DataBackupFileScreen({super.key, required this.onRecovered});

  Future<void> _recover(
    BuildContext context,
    WalletBackupImportSource source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          source == WalletBackupImportSource.file
              ? context.loc.dataBackupUseFile
              : context.loc.dataBackupUseServer,
        ),
        content: Text(context.loc.dataBackupFileApplyWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc.dataBackupRecover),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<DataBackupFileCubit>().recover(
        source,
        confirmed: true,
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<DataBackupFileCubit, DataBackupFileState>(
    listenWhen: (a, b) => a.result != b.result && b.result?.complete == true,
    listener: (_, state) {
      final comparison = state.comparison!;
      final snapshot = state.source == WalletBackupImportSource.server
          ? comparison.server!.snapshot!
          : comparison.file.snapshot;
      onRecovered(snapshot, state.result!);
    },
    builder: (context, state) {
      final comparison = state.comparison;
      return PopScope(
        canPop: !state.busy,
        child: Scaffold(
          appBar: AppBar(title: Text(context.loc.dataBackupImportFile)),
          body: SafeArea(
            child: comparison == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (state.busy) const LinearProgressIndicator(),
                      if (state.failure case final failure?)
                        Text(failure.toTranslated(context)),
                      if (state.result case final result?)
                        DataBackupRecoveryResult(result: result),
                      Text(context.loc.dataBackupFileComparison),
                      Text(
                        comparison.automaticBackupEnabled
                            ? context.loc.dataBackupFileAutomaticOn
                            : context.loc.dataBackupFileAutomaticOff,
                      ),
                      if (comparison.serverFailure != null)
                        Text(context.loc.dataBackupFileServerUnavailable),
                      if (comparison.server != null &&
                          comparison.server!.snapshot == null)
                        Text(context.loc.dataBackupMissing),
                      if (comparison.server?.snapshot != null)
                        Text(
                          comparison.differences.isEmpty
                              ? context.loc.dataBackupFileSame
                              : context.loc.dataBackupFileDifferent,
                        ),
                      for (final difference in comparison.differences)
                        Text(switch (difference) {
                          WalletBackupDifference.inventory =>
                            context.loc.dataBackupWallets,
                          WalletBackupDifference.metadata =>
                            context.loc.settingsAppSettingsTitle,
                          WalletBackupDifference.vaults =>
                            context.loc.bullVaultWalletLabel,
                        }),
                      const SizedBox(height: 16),
                      if (state.result?.complete != true) ...[
                        FilledButton(
                          key: const ValueKey('recover-data-file'),
                          onPressed: state.busy
                              ? null
                              : () => _recover(
                                  context,
                                  WalletBackupImportSource.file,
                                ),
                          child: Text(context.loc.dataBackupUseFile),
                        ),
                        if (comparison.server?.snapshot != null)
                          OutlinedButton(
                            key: const ValueKey('recover-data-server'),
                            onPressed: state.busy
                                ? null
                                : () => _recover(
                                    context,
                                    WalletBackupImportSource.server,
                                  ),
                            child: Text(context.loc.dataBackupUseServer),
                          ),
                      ] else
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.loc.continueButton),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '${context.loc.dataBackupFileCreated}: ${comparison.file.createdAt.toUtc().toIso8601String()}',
                      ),
                      DataBackupContents(
                        snapshot: comparison.file.snapshot,
                        source: DataBackupContentsSource.file,
                      ),
                      if (comparison.server?.snapshot case final snapshot?) ...[
                        const Divider(),
                        DataBackupContents(
                          snapshot: snapshot,
                          source: DataBackupContentsSource.server,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
