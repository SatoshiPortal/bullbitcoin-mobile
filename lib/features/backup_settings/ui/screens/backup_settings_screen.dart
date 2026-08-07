import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
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
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _BackupTestStatusWidget(),
                      ),
                      const Gap(40),
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

  const _StatusRow({required this.label, required this.isTested});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: context.font.bodyMedium),
        const Spacer(),
        Text(
          isTested
              ? context.loc.backupSettingsTested
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
    return SettingsEntryItem(
      icon: Icons.save_as,
      iconColor: context.appColors.primary,
      title: context.loc.backupSettingsStartBackup,
      onTap: () => context.pushNamed(
        BackupSettingsSubroute.backupOptions.name,
        extra: BackupSettingsFlow.backup,
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
