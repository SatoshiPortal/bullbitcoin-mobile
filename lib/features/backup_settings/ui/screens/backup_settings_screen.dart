import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_reminder_setting.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BackupSettingsCubit>()..checkBackupStatus(),
    child: const _RecoveryView(),
  );
}

class _RecoveryView extends StatelessWidget {
  const _RecoveryView();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(
              title: context.loc.walletRecoverySettingsTitle,
              onBack: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: state.status != BackupSettingsStatus.success
                ? Center(
                    child: state.failure == null
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.failure!.toTranslated(context)),
                              const Gap(12),
                              TextButton(
                                onPressed: context
                                    .read<BackupSettingsCubit>()
                                    .checkBackupStatus,
                                child: Text(context.loc.retry),
                              ),
                            ],
                          ),
                  )
                : _contents(context, state),
          ),
        ),
      );

  Widget _contents(BuildContext context, BackupSettingsState state) {
    final noBackup =
        !state.isDefaultPhysicalBackupTested &&
        !state.isDefaultEncryptedBackupTested;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Gap(8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              BackupTestStatusRow(
                label: context.loc.backupSettingsPhysicalBackup,
                testedAt: state.isDefaultPhysicalBackupTested
                    ? state.lastPhysicalBackup
                    : null,
              ),
              const Gap(15),
              BackupTestStatusRow(
                label: context.loc.backupSettingsEncryptedVault,
                testedAt: state.isDefaultEncryptedBackupTested
                    ? state.lastEncryptedBackup
                    : null,
              ),
            ],
          ),
        ),
        if (noBackup) ...[
          const Gap(32),
          _RecoveryWarningCard(
            urgent: true,
            title: context.loc.backupSettingsHeroBackUpTitle,
            body: context.loc.backupSettingsHeroBackUpBody,
            action: context.loc.backupSettingsStartBackupAction,
            onAction: () =>
                _openOptions(context, state, BackupSettingsFlow.backup),
          ),
        ] else ...[
          if (!state.isDefaultPhysicalBackupTested) ...[
            const Gap(32),
            _RecoveryWarningCard(
              title: context.loc.backupHealthReminderTitle,
              body: context.loc.backupHealthRecoverbullOnlyBody,
              action: context.loc.backupHealthAddPhysicalBackupAction,
              onAction: () => _refreshAfter(
                context,
                () => context.pushNamed<void>(
                  TestWalletBackupFacade.routeName,
                  extra: TestPhysicalBackupFlow.backup,
                ),
              ),
            ),
          ],
          const Gap(24),
          BBButton.big(
            label: context.loc.backupSettingsStartBackup,
            iconData: Icons.save_as,
            iconFirst: true,
            onPressed: () =>
                _openOptions(context, state, BackupSettingsFlow.backup),
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        ],
        const Gap(24),
        SettingsEntryItem(
          icon: Icons.vpn_key_outlined,
          title: context.loc.backupSettingsViewVaultKey,
          onTap: () => RecoverBullFacade.openViewVaultKey(context),
        ),
        if (state.lastPhysicalBackup != null ||
            state.lastEncryptedBackup != null)
          SettingsEntryItem(
            icon: Icons.verified_outlined,
            title: context.loc.backupSettingsTestBackup,
            onTap: () => _openOptions(context, state, BackupSettingsFlow.test),
          ),
        SettingsEntryItem(
          icon: Icons.cloud_outlined,
          title: context.loc.backupSettingsEncryptedVaultSettings,
          onTap: () => _refreshAfter(
            context,
            () => RecoverBullFacade.openSettings(context),
          ),
        ),
        SettingsEntryItem(
          icon: Icons.cloud_upload_outlined,
          title: context.loc.dataBackupTitle,
          onTap: () => _refreshAfter(
            context,
            () => context.pushNamed<void>(BackupSettingsRoute.dataBackup.name),
          ),
        ),
        const BackupDataExportEntries(),
        const Divider(),
        const BackupReminderSetting(),
        const Gap(24),
      ],
    );
  }

  Future<void> _openOptions(
    BuildContext context,
    BackupSettingsState state,
    BackupSettingsFlow flow,
  ) => _refreshAfter(
    context,
    () => context.pushNamed<void>(
      BackupSettingsSubroute.backupOptions.name,
      extra: BackupOptionsArgs(
        flow: flow,
        hasPhysicalBackup: state.lastPhysicalBackup != null,
        hasEncryptedBackup: state.lastEncryptedBackup != null,
      ),
    ),
  );

  Future<void> _refreshAfter(
    BuildContext context,
    Future<void> Function() open,
  ) async {
    await open();
    if (context.mounted) {
      await context.read<BackupSettingsCubit>().checkBackupStatus();
    }
  }
}

class _RecoveryWarningCard extends StatelessWidget {
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final bool urgent;

  const _RecoveryWarningCard({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = urgent
        ? context.appColors.error
        : context.appColors.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceContainer,
        border: Border.all(color: accent, width: urgent ? 2 : 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.font.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Text(body, style: context.font.bodyMedium),
          const Gap(16),
          BBButton.big(
            label: action,
            onPressed: onAction,
            bgColor: accent,
            textColor: context.appColors.surface,
          ),
        ],
      ),
    );
  }
}
