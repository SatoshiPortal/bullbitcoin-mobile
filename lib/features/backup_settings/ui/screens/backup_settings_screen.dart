import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<BackupSettingsCubit>()..checkBackupStatus(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (p, c) => p.failure != c.failure && c.failure != null,
      listener: (context, state) {
        SnackBarUtils.showSnackBar(
          context,
          state.failure!.toTranslated(context),
        );
      },
      child: BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              forceMaterialTransparency: true,
              automaticallyImplyLeading: false,
              flexibleSpace: TopBar(
                title: context.loc.backupSettingsScreenTitle,
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
                      const _WalletBackupSection(),
                      const Gap(32),
                      const _ProtectedDataSection(),
                      const Gap(32),
                      Text(
                        context.loc.backupSettingsRecoveryMethods,
                        style: context.font.titleMedium,
                      ),
                      const Gap(12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _BackupTestStatusWidget(),
                      ),
                      const Gap(24),
                      const _StartBackupButton(),
                      if (state.lastEncryptedBackup != null)
                        const _ViewVaultKeyButton(),
                      if (state.lastEncryptedBackup != null ||
                          state.lastPhysicalBackup != null)
                        const _TestBackupButton(),
                      const _RecoverBullSettingsButton(),
                      const _Bip329LabelsButton(),
                      const _TransactionHistoryButton(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
                title: context.loc.walletBackupMetadataRow(
                  contents.metadataRecordCount,
                ),
                onTap: () => context.pushNamed(
                  BackupSettingsSubroute.walletMetadata.name,
                  extra: contents.metadata,
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
            SettingsEntryItem(
              icon: Icons.key_outlined,
              title: context.loc.walletBackupNostrIdentities,
              onTap: () => context.pushNamed(KeychainManifestRoutes.listName),
            ),
          ],
        );
      },
    );
  }
}

class _WalletBackupSection extends StatelessWidget {
  const _WalletBackupSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      buildWhen: (previous, current) =>
          previous.walletBackup != current.walletBackup ||
          previous.walletBackupOperation != current.walletBackupOperation ||
          previous.lastRecoveryOutcome != current.lastRecoveryOutcome,
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.loc.walletBackupSettingsEnabled),
              subtitle: Text(_walletBackupStatus(context, backup)),
              value: backup.enabled,
              onChanged: busy
                  ? null
                  : (enabled) => _setEnabled(context, enabled),
            ),
            if (state.lastRecoveryOutcome case final outcome?
                when outcome.status != WalletBackupRecoveryStatus.noBackup)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _walletBackupRecoveryStatus(context, outcome),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
              ),
            if (backup.enabled)
              SettingsEntryItem(
                icon: Icons.cloud_upload_outlined,
                title: context.loc.walletBackupSettingsBackupNow,
                onTap: busy
                    ? null
                    : context.read<BackupSettingsCubit>().backupWalletNow,
              ),
            if (state.canRetryRecovery)
              SettingsEntryItem(
                icon: Icons.restore,
                title: context.loc.walletBackupSettingsRecoveryBlocked,
                onTap: context
                    .read<BackupSettingsCubit>()
                    .retryWalletBackupRecovery,
              ),
            SettingsEntryItem(
              icon: Icons.delete_outline,
              iconColor: context.appColors.error,
              textColor: context.appColors.error,
              title: context.loc.walletBackupSettingsDelete,
              onTap: busy ? null : () => _confirmDelete(context),
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
  return context.loc.walletBackupSettingsLastBackup(
    MaterialLocalizations.of(context).formatMediumDate(date),
  );
}

String _walletBackupRecoveryStatus(
  BuildContext context,
  WalletBackupRecoveryOutcome outcome,
) => switch (outcome.status) {
  WalletBackupRecoveryStatus.restored =>
    context.loc.walletBackupSettingsRecoveryComplete,
  WalletBackupRecoveryStatus.newerVersion =>
    context.loc.walletBackupSettingsUpdateRequired,
  WalletBackupRecoveryStatus.noBackup => '',
  _ => context.loc.walletBackupSettingsRecoveryIncomplete,
};

class _BackupTestStatusWidget extends StatelessWidget {
  const _BackupTestStatusWidget();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: .start,
          children: [
            _StatusRow(
              label: context.loc.backupSettingsPhysicalBackup,
              isTested: state.isDefaultPhysicalBackupTested,
              testedAt: state.lastPhysicalBackup,
            ),
            const Gap(15),
            _StatusRow(
              label: context.loc.backupSettingsEncryptedVault,
              isTested: state.isDefaultEncryptedBackupTested,
              testedAt: state.lastEncryptedBackup,
            ),
          ],
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isTested;
  final DateTime? testedAt;

  const _StatusRow({
    required this.label,
    required this.isTested,
    required this.testedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: context.font.bodyMedium),
        const Spacer(),
        Text(
          isTested
              ? testedAt == null
                    ? context.loc.backupSettingsTested
                    : context.loc.backupSettingsTestedOn(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(testedAt!.toLocal()),
                      )
              : context.loc.backupSettingsNotTested,
          style: context.font.bodyMedium?.copyWith(
            color: isTested
                ? context.appColors.success
                : context.appColors.error,
          ),
        ),
      ],
    );
  }
}

class _TestBackupButton extends StatelessWidget {
  const _TestBackupButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.verified,
      title: context.loc.backupSettingsTestBackup,
      onTap: () => context.pushNamed(
        BackupSettingsSubroute.backupOptions.name,
        extra: BackupSettingsFlow.test,
      ),
    );
  }
}

class _StartBackupButton extends StatelessWidget {
  const _StartBackupButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.save_as),
        label: Text(context.loc.backupSettingsStartBackup),
        onPressed: () => context.pushNamed(
          BackupSettingsSubroute.backupOptions.name,
          extra: BackupSettingsFlow.backup,
        ),
      ),
    );
  }
}

class _ViewVaultKeyButton extends StatelessWidget {
  const _ViewVaultKeyButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.vpn_key,
      title: context.loc.backupSettingsViewVaultKey,
      onTap: () async {
        final confirmed = await ViewVaultKeyWarningBottomSheet.show(context);
        if (confirmed == true) {
          if (!context.mounted) return;
          await context.pushNamed(
            RecoverBullRoute.recoverbullFlows.name,
            extra: RecoverBullFlowsExtra(
              flow: RecoverBullFlow.viewVaultKey,
              vault: null,
            ),
          );
        }
      },
    );
  }
}

class _TransactionHistoryButton extends StatelessWidget {
  const _TransactionHistoryButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.file_download,
      title: context.loc.transactionHistoryTitle,
      onTap: () => context.pushNamed(TransactionsRoute.exportTransactions.name),
    );
  }
}

class _Bip329LabelsButton extends StatelessWidget {
  const _Bip329LabelsButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.sell,
      title: context.loc.backupSettingsLabelsButton,
      onTap: () => context.push(LabelsRouter.route.path),
    );
  }
}

class _RecoverBullSettingsButton extends StatelessWidget {
  const _RecoverBullSettingsButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.cloud_circle,
      iconColor: context.appColors.secondary,
      textColor: context.appColors.secondary,
      title: context.loc.backupSettingsRecoverBullSettings,
      onTap: () {
        context.pushNamed(
          RecoverBullRoute.recoverbullFlows.name,
          extra: RecoverBullFlowsExtra(
            flow: RecoverBullFlow.settings,
            vault: null,
          ),
        );
      },
    );
  }
}
