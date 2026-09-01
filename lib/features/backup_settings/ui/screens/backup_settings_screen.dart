import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_server_editor_dialog.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/wallet_backup_file_actions.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch, Gap;
import 'package:go_router/go_router.dart';

class DataBackupSettingsScreen extends StatelessWidget {
  const DataBackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<BackupSettingsCubit>()..loadDataBackup(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (p, c) =>
          (p.failure != c.failure && c.failure != null) ||
          p.fileExportReady != c.fileExportReady ||
          p.fileComparison != c.fileComparison ||
          p.fileRecoveryResult != c.fileRecoveryResult,
      listener: (context, state) async {
        final failure = state.failure;
        if (failure != null) {
          SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
          return;
        }
        if (state.fileExportReady) {
          SnackBarUtils.showSnackBar(
            context,
            context.loc.walletBackupFileExported,
          );
          return;
        }
        final comparison = state.fileComparison;
        if (comparison != null) {
          final source = await _showBackupComparison(context, comparison);
          if (!context.mounted) return;
          if (source == null) {
            context.read<BackupSettingsCubit>().cancelBackupFileImport();
          } else {
            await context.read<BackupSettingsCubit>().recoverSelectedBackup(
              source,
            );
          }
          return;
        }
        final result = state.fileRecoveryResult;
        if (result != null) {
          SnackBarUtils.showSnackBar(
            context,
            _walletBackupFileRecoveryStatus(context, result),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.dataBackupSettingsTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  const Gap(8),
                  Text(
                    context.loc.dataBackupNoSecretsDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                  const Gap(24),
                  const _WalletBackupSection(),
                  const Gap(32),
                  const _ProtectedDataSection(),
                  const Gap(32),
                  const _ManualBackupSection(),
                  const Gap(32),
                  const _DataExportsSection(),
                  const Gap(32),
                  const _AdvancedBackupSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<WalletBackupImportSource?> _showBackupComparison(
  BuildContext context,
  WalletBackupImportComparison comparison,
) => showDialog<WalletBackupImportSource>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
    title: Text(dialogContext.loc.walletBackupFileCompareTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_comparisonExplanation(dialogContext, comparison.situation)),
          const Gap(16),
          _BackupSummary(
            title: dialogContext.loc.walletBackupFileFileSummary,
            summary: comparison.file,
          ),
          if (comparison.server case final server?) ...[
            const Gap(12),
            _BackupSummary(
              title: dialogContext.loc.walletBackupFileServerSummary,
              summary: server,
            ),
          ],
          if (comparison.differences.isNotEmpty) ...[
            const Gap(12),
            Text(
              dialogContext.loc.walletBackupFileDifferences(
                _differenceLabels(
                  dialogContext,
                  comparison.differences,
                ).join(', '),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(dialogContext.loc.walletBackupFileCancelImport),
      ),
      if (comparison.server != null)
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, WalletBackupImportSource.server),
          child: Text(dialogContext.loc.walletBackupFileUseServer),
        ),
      TextButton(
        onPressed: () =>
            Navigator.pop(dialogContext, WalletBackupImportSource.file),
        child: Text(dialogContext.loc.walletBackupFileUseFile),
      ),
    ],
  ),
);

class _BackupSummary extends StatelessWidget {
  final String title;
  final WalletBackupSnapshotSummary summary;

  const _BackupSummary({required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(
      summary.createdAt * 1000,
      isUtc: true,
    ).toLocal();
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.font.titleSmall),
        const Gap(4),
        Text(
          context.loc.walletBackupFileSummaryCounts(
            summary.walletCount,
            summary.nostrIdentityCount,
            summary.externalWalletCount,
          ),
        ),
        Text(
          context.loc.walletBackupFileProtectedDataCounts(
            summary.labelCount,
            summary.frozenOutpointCount,
            summary.walletPreferenceCount,
          ),
        ),
        Text(
          context.loc.walletBackupFileSummaryDate(
            '${material.formatMediumDate(created)} '
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(created))}',
          ),
        ),
      ],
    );
  }
}

List<String> _differenceLabels(
  BuildContext context,
  Set<WalletBackupDifference> differences,
) => [
  if (differences.contains(WalletBackupDifference.walletManifest))
    context.loc.walletBackupManifestTitle,
  if (differences.contains(WalletBackupDifference.externalWallets))
    context.loc.walletBackupFileExternalWallets,
  if (differences.contains(WalletBackupDifference.protectedData))
    context.loc.walletBackupContentsTitle,
];

String _comparisonExplanation(
  BuildContext context,
  WalletBackupImportSituation situation,
) => switch (situation) {
  WalletBackupImportSituation.automaticBackupDisabled =>
    context.loc.walletBackupFileAutomaticDisabledExplanation,
  WalletBackupImportSituation.serverUnavailable =>
    context.loc.walletBackupFileServerUnavailableExplanation,
  WalletBackupImportSituation.noServerBackup =>
    context.loc.walletBackupFileNoServerExplanation,
  WalletBackupImportSituation.same =>
    context.loc.walletBackupFileSameExplanation,
  WalletBackupImportSituation.different =>
    context.loc.walletBackupFileDifferentExplanation,
};

class _ProtectedDataSection extends StatelessWidget {
  const _ProtectedDataSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      buildWhen: (previous, current) =>
          previous.contents != current.contents ||
          previous.contentsLoading != current.contentsLoading,
      builder: (context, state) {
        final contents = state.contents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.walletBackupContentsTitle,
              style: context.font.titleMedium,
            ),
            const Gap(6),
            Text(
              context.loc.walletBackupContentsDescription,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            if (contents != null) ...[
              SettingsEntryItem(
                icon: Icons.account_balance_wallet_outlined,
                title: context.loc.walletBackupManifestRow(
                  contents.wallets.length,
                ),
                onTap: () => context.pushNamed(
                  BackupSettingsSubroute.walletManifest.name,
                  extra: contents.wallets,
                ),
              ),
              SettingsEntryItem(
                icon: Icons.description_outlined,
                title: context.loc.walletBackupMetadataRow,
                onTap: () => context.pushNamed(
                  BackupSettingsSubroute.walletMetadata.name,
                  extra: contents,
                ),
              ),
            ] else if (state.contentsLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SettingsEntryItem(
                icon: Icons.refresh,
                title: context.loc.walletBackupContentsRetry,
                onTap: context.read<BackupSettingsCubit>().loadContents,
              ),
          ],
        );
      },
    );
  }
}

String _walletBackupFileRecoveryStatus(
  BuildContext context,
  WalletBackupRecoveryResult result,
) => switch (result.status) {
  WalletBackupRecoveryStatus.restored => context.loc.walletBackupFileRestored(
    result.restoredCount,
  ),
  WalletBackupRecoveryStatus.partiallyRestored =>
    context.loc.walletBackupSettingsRecoveryIncomplete,
  WalletBackupRecoveryStatus.newerVersion =>
    context.loc.walletBackupSettingsUpdateRequired,
  WalletBackupRecoveryStatus.conflict ||
  WalletBackupRecoveryStatus.invalid => context.loc.walletBackupFileInvalid,
  _ => context.loc.walletBackupFileRecoveryFailed,
};

class _WalletBackupSection extends StatelessWidget {
  const _WalletBackupSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      buildWhen: (previous, current) =>
          previous.walletBackup != current.walletBackup ||
          previous.walletBackupBusy != current.walletBackupBusy,
      builder: (context, state) {
        final backup = state.walletBackup;
        if (backup == null) return const SizedBox.shrink();
        final busy = state.walletBackupBusy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.walletBackupSettingsTitle,
              style: context.font.titleMedium,
            ),
            const Gap(6),
            Text(
              context.loc.walletBackupSettingsDescription,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            InkWell(
              onTap: busy ? null : () => _setEnabled(context, !backup.enabled),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.loc.walletBackupSettingsEnabled),
                        Text(
                          _walletBackupStatus(context, backup),
                          style: context.font.bodySmall?.copyWith(
                            color: context.appColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BullSwitch(
                    value: backup.enabled,
                    onChanged: busy
                        ? null
                        : (enabled) => _setEnabled(context, enabled),
                  ),
                ],
              ),
            ),
            if (backup.lastRecoveryStatus case final status?
                when status != WalletBackupRecoveryStatus.noBackup)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _walletBackupRecoveryStatus(context, status),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
              ),
            if (backup.enabled && !backup.recoveryBlocked)
              BBButton.big(
                label: context.loc.walletBackupSettingsBackupNow,
                iconData: Icons.cloud_upload_outlined,
                iconFirst: true,
                disabled: busy,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                onPressed: context.read<BackupSettingsCubit>().backupWalletNow,
              ),
            if (state.canRetryRecovery)
              SettingsEntryItem(
                icon: Icons.restore,
                title: backup.needsAttention
                    ? context.loc.walletBackupSettingsFinishReconciliation
                    : context.loc.walletBackupSettingsRecoveryBlocked,
                onTap: context
                    .read<BackupSettingsCubit>()
                    .retryWalletBackupRecovery,
              ),
          ],
        );
      },
    );
  }

  Future<void> _setEnabled(BuildContext context, bool enabled) async {
    if (!enabled) {
      await context.read<BackupSettingsCubit>().setWalletBackupEnabled(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.walletMetadataBackupConsentTitle),
        content: Text(dialogContext.loc.walletMetadataBackupConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.loc.walletMetadataBackupConsentCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.loc.walletMetadataBackupConsentContinue),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BackupSettingsCubit>().setWalletBackupEnabled(true);
    }
  }
}

class _ManualBackupSection extends StatelessWidget {
  const _ManualBackupSection();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        buildWhen: (previous, current) =>
            previous.walletBackupBusy != current.walletBackupBusy,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.walletBackupManualSectionTitle,
              style: context.font.titleMedium,
            ),
            const Gap(8),
            WalletBackupFileActions(
              busy: state.walletBackupBusy,
              onExport: (protection, confirmed) =>
                  context.read<BackupSettingsCubit>().exportBackupFile(
                    protection: protection,
                    confirmedUnencrypted: confirmed,
                  ),
              onImport: context.read<BackupSettingsCubit>().importBackupFile,
            ),
          ],
        ),
      );
}

class _DataExportsSection extends StatelessWidget {
  const _DataExportsSection();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.loc.walletBackupDataExportsTitle,
        style: context.font.titleMedium,
      ),
      const Gap(8),
      SettingsEntryItem(
        icon: Icons.sell_outlined,
        title: context.loc.backupSettingsLabelsButton,
        onTap: () async {
          await context.push(LabelsRouter.route.path);
          if (context.mounted) {
            await context.read<BackupSettingsCubit>().loadContents();
          }
        },
      ),
      SettingsEntryItem(
        icon: Icons.file_download_outlined,
        title: context.loc.transactionHistoryTitle,
        onTap: () =>
            context.pushNamed(TransactionsRoute.exportTransactions.name),
      ),
    ],
  );
}

class _AdvancedBackupSection extends StatelessWidget {
  const _AdvancedBackupSection();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        buildWhen: (previous, current) =>
            previous.walletBackup != current.walletBackup ||
            previous.walletBackupBusy != current.walletBackupBusy,
        builder: (context, state) {
          final backup = state.walletBackup;
          if (backup == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.loc.walletBackupAdvancedTitle,
                style: context.font.titleMedium,
              ),
              const Gap(8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dns_outlined),
                title: Text(context.loc.walletBackupSettingsServer),
                subtitle: Text(
                  backup.customServerUrl ?? walletBackupDefaultServerUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: state.walletBackupBusy
                    ? null
                    : () => _editServer(context, backup.customServerUrl),
              ),
              SettingsEntryItem(
                icon: Icons.delete_outline,
                iconColor: context.appColors.error,
                textColor: context.appColors.error,
                title: context.loc.walletBackupSettingsDelete,
                onTap: state.walletBackupBusy
                    ? null
                    : () => _confirmDelete(context),
              ),
            ],
          );
        },
      );

  Future<void> _editServer(BuildContext context, String? current) async {
    final value = await showBackupServerEditorDialog(context, current: current);
    if (value != null && context.mounted) {
      await context.read<BackupSettingsCubit>().setWalletBackupServer(value);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.walletBackupSettingsDeleteTitle),
        content: Text(dialogContext.loc.walletBackupSettingsDeleteDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.loc.walletBackupSettingsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.loc.walletBackupSettingsDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BackupSettingsCubit>().deleteWalletBackup();
    }
  }
}

String _walletBackupStatus(BuildContext context, WalletBackupState state) {
  if (!state.enabled) return context.loc.walletBackupSettingsOff;
  if (state.needsAttention) {
    return context.loc.walletBackupSettingsReconciliationPending;
  }
  if (state.recoveryBlocked) {
    return context.loc.walletBackupSettingsRecoveryBlocked;
  }
  if (state.unsupportedVersion != null) {
    return context.loc.walletBackupSettingsUpdateRequired;
  }
  if (state.dirty) return context.loc.walletBackupSettingsPending;
  final succeededAt = state.lastSucceededAt;
  if (succeededAt == null) return context.loc.walletBackupSettingsNeverBackedUp;
  final date = DateTime.fromMillisecondsSinceEpoch(
    succeededAt * 1000,
    isUtc: true,
  ).toLocal();
  final localizations = MaterialLocalizations.of(context);
  return context.loc.walletBackupSettingsLastBackup(
    '${localizations.formatMediumDate(date)}, '
    '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
  );
}

String _walletBackupRecoveryStatus(
  BuildContext context,
  WalletBackupRecoveryStatus status,
) => switch (status) {
  WalletBackupRecoveryStatus.restored =>
    context.loc.walletBackupSettingsRecoveryComplete,
  WalletBackupRecoveryStatus.newerVersion =>
    context.loc.walletBackupSettingsUpdateRequired,
  WalletBackupRecoveryStatus.noBackup => '',
  _ => context.loc.walletBackupSettingsRecoveryIncomplete,
};
