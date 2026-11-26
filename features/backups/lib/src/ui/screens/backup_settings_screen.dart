import 'package:backups/src/backups_l10n.dart';
import 'package:backups/src/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:backups/src/presentation/cubit/backup_settings_cubit.dart';
import 'package:backups/src/backups_feature.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:label_editor/label_editor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullSettingsEntryItem,
        BullSnackBar,
        BullTopBar,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class BackupSettingsScreen extends StatelessWidget {
  final VoidCallback onExportTransactions;
  final VoidCallback? onOpenAutomaticBackup;
  final String? Function(BuildContext)? automaticBackupStatus;

  const BackupSettingsScreen({
    super.key,
    required this.onExportTransactions,
    this.onOpenAutomaticBackup,
    this.automaticBackupStatus,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (p, c) => p.failure != c.failure && c.failure != null,
      listener: (context, state) {
        BullSnackBar.show(
          context,
          message: switch (state.failure) {
            final failure? => failure.toTranslated(context),
            null => context.loc.oopsSomethingWentWrong,
          },
        );
      },
      child: BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              forceMaterialTransparency: true,
              automaticallyImplyLeading: false,
              flexibleSpace: BullTopBar(
                title: context.loc.settingsBackupTitle,
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
                      _BackupSectionHeader(
                        title: context.loc.backupSettingsMoneySection,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _BackupTestStatusWidget(),
                      ),
                      const Gap(16),
                      BullSettingsEntryItem(
                        icon: Icons.save_as,
                        iconColor: context.bull.primary,
                        title: context.loc.backupSettingsStartBackup,
                        onTap: () => BackupsNavigation.start(context),
                      ),
                      if (state.lastEncryptedBackup != null ||
                          state.lastPhysicalBackup != null)
                        const _TestBackupButton(),
                      BullSettingsEntryItem(
                        icon: Icons.cloud_circle,
                        iconColor: context.bull.secondary,
                        textColor: context.bull.secondary,
                        title: context.loc.backupSettingsRecoverBullSettings,
                        onTap: () => RecoverBullFeature.open(
                          context,
                          RecoverBullFlow.settings,
                        ),
                      ),
                      if (state.lastEncryptedBackup != null)
                        const _ViewVaultKeyButton(),
                      const Gap(16),
                      _BackupSectionHeader(
                        title: context.loc.backupSettingsDataSection,
                      ),
                      if (onOpenAutomaticBackup case final open?)
                        BullSettingsEntryItem(
                          icon: Icons.cloud_upload,
                          title: context.loc.backupSettingsAutomaticBackup,
                          subtitle:
                              automaticBackupStatus?.call(context) ??
                              context.loc.coreScreensUnknown,
                          onTap: open,
                        ),
                      BullSettingsEntryItem(
                        icon: Icons.sell,
                        title: context.loc.backupSettingsLabelsButton,
                        onTap: () => LabelEditor.open(context),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.file_download,
                        title: context.loc.transactionHistoryTitle,
                        onTap: onExportTransactions,
                      ),
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

class _BackupSectionHeader extends StatelessWidget {
  final String title;

  const _BackupSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: context.bullType.label.copyWith(color: context.bull.textMuted),
      ),
    ),
  );
}

class _ViewVaultKeyButton extends StatelessWidget {
  const _ViewVaultKeyButton();

  @override
  Widget build(BuildContext context) => BullSettingsEntryItem(
    icon: Icons.vpn_key,
    title: context.loc.backupSettingsViewVaultKey,
    onTap: () => RecoverBullFeature.open(context, RecoverBullFlow.viewVaultKey),
  );
}

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
            ),
            const Gap(15),
            _StatusRow(
              label: context.loc.backupSettingsEncryptedVault,
              isTested: state.isDefaultEncryptedBackupTested,
              unknown: state.isDefaultEncryptedBackupHistorical,
            ),
            if (state.isDefaultEncryptedBackupHistorical)
              const RecoverBullHistoricalWarning(),
          ],
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isTested;
  final bool unknown;

  const _StatusRow({
    required this.label,
    required this.isTested,
    this.unknown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: context.bullType.body),
        const Spacer(),
        Text(
          isTested
              ? context.loc.backupSettingsTested
              : unknown
              ? context.loc.coreScreensUnknown
              : context.loc.backupSettingsNotTested,
          style: context.bullType.body.copyWith(
            color: isTested ? context.bull.success : context.bull.error,
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
    return BullSettingsEntryItem(
      icon: Icons.verified,
      title: context.loc.backupSettingsTestBackup,
      onTap: () => BackupsNavigation.verify(context),
    );
  }
}
