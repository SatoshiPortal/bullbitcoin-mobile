import 'package:bull_ui/bull_ui.dart' show BullButton, BullSpacing, Gap;
import 'package:bb_mobile/core/themes/app_theme.dart';
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
    listenWhen: (previous, current) =>
        current is DataBackupFilePreview &&
        current.result?.complete == true &&
        (previous is! DataBackupFilePreview ||
            previous.result != current.result),
    listener: (_, state) {
      if (state case DataBackupFilePreview(
        :final comparison,
        :final source,
        result: final result?,
      )) {
        final snapshot = source == WalletBackupImportSource.server
            ? comparison.server!.snapshot!
            : comparison.file.snapshot;
        onRecovered(snapshot, result);
      }
    },
    builder: (context, state) {
      if (state is! DataBackupFilePreview) return const SizedBox.shrink();
      final comparison = state.comparison;
      return PopScope(
        canPop: !state.busy,
        child: Scaffold(
          appBar: AppBar(title: Text(context.loc.dataBackupImportFile)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(BullSpacing.lg),
              children: [
                if (state.busy) ...[
                  const LinearProgressIndicator(),
                  const Gap(BullSpacing.md),
                ],
                if (state.failure case final failure?) ...[
                  Text(failure.toTranslated(context)),
                  const Gap(BullSpacing.md),
                ],
                if (state.result case final result?) ...[
                  DataBackupRecoveryResult(result: result),
                  const Gap(BullSpacing.lg),
                ],
                Text(
                  context.loc.dataBackupFileComparison,
                  style: context.font.titleMedium,
                ),
                const Gap(BullSpacing.md),
                Text(
                  comparison.automaticBackupEnabled
                      ? context.loc.dataBackupFileAutomaticOn
                      : context.loc.dataBackupFileAutomaticOff,
                ),
                const Gap(BullSpacing.md),
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
                const Gap(BullSpacing.xs),
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
                  BullButton.big(
                    maxLines: null,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    disabled: state.busy,
                    key: const ValueKey('recover-data-file'),
                    onPressed: () =>
                        _recover(context, WalletBackupImportSource.file),
                    label: context.loc.dataBackupUseFile,
                  ),
                  if (comparison.server?.snapshot != null) ...[
                    const Gap(BullSpacing.md),
                    BullButton.big(
                      maxLines: null,
                      outlined: true,
                      bgColor: context.appColors.secondary,
                      textColor: context.appColors.onSecondary,
                      disabled: state.busy,
                      key: const ValueKey('recover-data-server'),
                      onPressed: () =>
                          _recover(context, WalletBackupImportSource.server),
                      label: context.loc.dataBackupUseServer,
                    ),
                  ],
                ] else
                  BullButton.big(
                    maxLines: null,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    onPressed: () => Navigator.pop(context),
                    label: context.loc.continueButton,
                  ),
                const SizedBox(height: 16),
                Text(
                  '${context.loc.dataBackupFileCreated}: ${comparison.file.createdAt.toUtc().toIso8601String()}',
                ),
                const Gap(BullSpacing.lg),
                DataBackupContents(
                  snapshot: comparison.file.snapshot,
                  source: DataBackupContentsSource.file,
                ),
                if (comparison.server?.snapshot case final snapshot?) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: BullSpacing.lg),
                    child: Divider(),
                  ),
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
