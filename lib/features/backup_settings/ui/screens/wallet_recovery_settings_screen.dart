import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/wallet_recovery_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_routes.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_routes.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletRecoverySettingsScreen extends StatelessWidget {
  const WalletRecoverySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<WalletRecoverySettingsCubit>()..load(),
    child: const _WalletRecoveryView(),
  );
}

class _WalletRecoveryView extends StatelessWidget {
  const _WalletRecoveryView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<
      WalletRecoverySettingsCubit,
      WalletRecoverySettingsState
    >(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => SnackBarUtils.showSnackBar(
        context,
        state.failure!.toTranslated(context),
      ),
      child:
          BlocBuilder<WalletRecoverySettingsCubit, WalletRecoverySettingsState>(
            builder: (context, state) {
              final hero = _postureHero(context, state);
              return Scaffold(
                appBar: AppBar(
                  forceMaterialTransparency: true,
                  automaticallyImplyLeading: false,
                  flexibleSpace: TopBar(
                    title: context.loc.walletRecoverySettingsTitle,
                    onBack: () => context.pop(),
                  ),
                ),
                body: SafeArea(
                  child: !state.loaded
                      ? _RecoveryStatusLoading(failure: state.failure)
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            const Gap(8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  _StatusRow(
                                    label: context
                                        .loc
                                        .backupSettingsPhysicalBackup,
                                    testedAt: state.lastPhysicalBackup,
                                  ),
                                  const Gap(15),
                                  _StatusRow(
                                    label: context
                                        .loc
                                        .backupSettingsEncryptedVault,
                                    testedAt: state.lastEncryptedBackup,
                                  ),
                                ],
                              ),
                            ),
                            if (hero != null) ...[const Gap(32), hero],
                            if (!state.hasNoBackup) ...[
                              const Gap(24),
                              BBButton.big(
                                label: context.loc.backupSettingsStartBackup,
                                iconData: Icons.save_as,
                                iconFirst: true,
                                onPressed: () => _openBackupOptions(
                                  context,
                                  BackupSettingsFlow.backup,
                                ),
                                bgColor: context.appColors.primary,
                                textColor: context.appColors.onPrimary,
                              ),
                            ],
                            const Gap(24),
                            if (state.hasEncryptedBackup)
                              const _ViewVaultKeyButton(),
                            if (state.hasEncryptedBackup ||
                                state.hasPhysicalBackup)
                              SettingsEntryItem(
                                icon: Icons.verified_outlined,
                                title: context.loc.backupSettingsTestBackup,
                                onTap: () => _openBackupOptions(
                                  context,
                                  BackupSettingsFlow.test,
                                ),
                              ),
                            SettingsEntryItem(
                              icon: Icons.cloud_outlined,
                              title: context
                                  .loc
                                  .backupSettingsEncryptedVaultSettings,
                              onTap: () => _openRecoverBull(context),
                            ),
                            const Divider(),
                            const _BackupReminderSetting(),
                          ],
                        ),
                ),
              );
            },
          ),
    );
  }

  Widget? _postureHero(
    BuildContext context,
    WalletRecoverySettingsState state,
  ) {
    if (!state.loaded) return null;
    if (state.hasNoBackup) {
      return _HeroCard(
        urgent: true,
        title: context.loc.backupSettingsHeroBackUpTitle,
        body: context.loc.backupSettingsHeroBackUpBody,
        action: context.loc.backupSettingsStartBackupAction,
        onAction: () => _openBackupOptions(context, BackupSettingsFlow.backup),
      );
    }
    if (!state.hasPhysicalBackup && state.hasEncryptedBackup) {
      return _HeroCard(
        title: context.loc.backupHealthReminderTitle,
        body: context.loc.backupHealthRecoverbullOnlyBody,
        action: context.loc.backupHealthAddPhysicalBackupAction,
        onAction: () => _openPhysicalBackup(context),
      );
    }
    return null;
  }

  Future<void> _openBackupOptions(
    BuildContext context,
    BackupSettingsFlow flow,
  ) async {
    await context.pushNamed(
      BackupSettingsSubroute.backupOptions.name,
      extra: BackupOptionsArgs(
        flow: flow,
        hasPhysicalBackup: context
            .read<WalletRecoverySettingsCubit>()
            .state
            .hasPhysicalBackup,
        hasEncryptedBackup: context
            .read<WalletRecoverySettingsCubit>()
            .state
            .hasEncryptedBackup,
      ),
    );
    if (context.mounted) {
      await context.read<WalletRecoverySettingsCubit>().load();
    }
  }

  Future<void> _openPhysicalBackup(BuildContext context) async {
    await context.pushNamed(
      TestWalletBackupRoute.testPhysicalBackupFlow.name,
      extra: TestPhysicalBackupFlow.backup,
    );
    if (context.mounted) {
      await context.read<WalletRecoverySettingsCubit>().load();
    }
  }

  Future<void> _openRecoverBull(BuildContext context) async {
    await context.pushNamed(
      RecoverBullRoute.recoverbullFlows.name,
      extra: RecoverBullFlowsExtra(flow: RecoverBullFlow.settings, vault: null),
    );
    if (context.mounted) {
      await context.read<WalletRecoverySettingsCubit>().load();
    }
  }
}

class _RecoveryStatusLoading extends StatelessWidget {
  final BackupSettingsFailure? failure;

  const _RecoveryStatusLoading({this.failure});

  @override
  Widget build(BuildContext context) => Center(
    child: failure == null
        ? const CircularProgressIndicator()
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(failure!.toTranslated(context)),
              const Gap(12),
              TextButton(
                onPressed: context.read<WalletRecoverySettingsCubit>().load,
                child: Text(context.loc.retry),
              ),
            ],
          ),
  );
}

class _BackupReminderSetting extends StatelessWidget {
  const _BackupReminderSetting();

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupReminderCubit, BackupReminderState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => SnackBarUtils.showSnackBar(
        context,
        state.failure!.toTranslated(context),
      ),
      child: BlocBuilder<BackupReminderCubit, BackupReminderState>(
        buildWhen: (previous, current) =>
            previous.dismissForever != current.dismissForever,
        builder: (context, state) => InkWell(
          onTap: () => _set(context, !state.dismissForever),
          child: Row(
            children: [
              Expanded(child: Text(context.loc.backupReminderDismissForever)),
              BullSwitch(
                value: state.dismissForever,
                onChanged: (value) => _set(context, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, bool value) async {
    if (!value) {
      await context.read<BackupReminderCubit>().setDismissForever(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.backupReminderDismissForeverConfirmTitle),
        content: Text(
          dialogContext.loc.backupReminderDismissForeverConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.loc.backupReminderDismissForeverConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BackupReminderCubit>().setDismissForever(true);
    }
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final bool urgent;

  const _HeroCard({
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
      width: double.infinity,
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
          Text(
            body,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
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

class _StatusRow extends StatelessWidget {
  final String label;
  final DateTime? testedAt;

  const _StatusRow({required this.label, required this.testedAt});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: context.font.bodyMedium),
          const Spacer(),
          Text(
            testedAt != null
                ? context.loc.backupSettingsTested
                : context.loc.backupSettingsNotTested,
            style: context.font.bodyMedium?.copyWith(
              color: testedAt != null
                  ? context.appColors.success
                  : context.appColors.error,
            ),
          ),
        ],
      ),
      if (testedAt != null)
        Text(
          context.loc.backupSettingsTestedOn(
            _formatDateTime(context, testedAt!.toLocal()),
          ),
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.onSurfaceVariant,
          ),
        ),
    ],
  );
}

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(value)}, '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}

class _ViewVaultKeyButton extends StatelessWidget {
  const _ViewVaultKeyButton();

  @override
  Widget build(BuildContext context) => SettingsEntryItem(
    icon: Icons.vpn_key_outlined,
    title: context.loc.backupSettingsViewVaultKey,
    onTap: () async {
      final confirmed = await ViewVaultKeyWarningBottomSheet.show(context);
      if (confirmed == true && context.mounted) {
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
