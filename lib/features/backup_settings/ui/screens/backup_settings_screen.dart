import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/bip329_labels/router.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(20),
                  const _BackupTestStatusWidget(),
                  const Spacer(),
                  if (state.lastEncryptedBackup != null) ...[
                    const _ViewVaultKeyButton(),
                    const Gap(12),
                  ],
                  if (state.lastEncryptedBackup != null ||
                      state.lastPhysicalBackup != null) ...[
                    const _TestBackupButton(),
                    const Gap(12),
                  ],
                  const _StartBackupButton(),
                  const Gap(12),
                  const _Bip329LabelsButton(),
                  const Gap(12),
                  const _RecoverBullSettingsButton(),
                  const Gap(20),
                  if (state.error != null) ErrorWidget(error: state.error!),
                ],
              ),
            ),
          ),
        );
      },
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            color:
                isTested ? context.colour.inverseSurface : context.colour.error,
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
    return BBButton.big(
      label: context.loc.backupSettingsTestBackup,
      onPressed:
          () => context.pushNamed(
            BackupSettingsSubroute.backupOptions.name,
            extra: BackupSettingsFlow.test,
          ),
      borderColor: context.colour.secondary,
      outlined: true,
      bgColor: Colors.transparent,
      textColor: context.colour.secondary,
    );
  }
}

class _StartBackupButton extends StatelessWidget {
  const _StartBackupButton();

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: context.loc.backupSettingsStartBackup,
      onPressed:
          () => context.pushNamed(
            BackupSettingsSubroute.backupOptions.name,
            extra: BackupSettingsFlow.backup,
          ),
      bgColor: context.colour.primary,
      textColor: context.colour.onPrimary,
    );
  }
}

class _ViewVaultKeyButton extends StatelessWidget {
  const _ViewVaultKeyButton();

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: context.loc.backupSettingsViewVaultKey,
      onPressed: () async {
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
      borderColor: context.colour.secondary,
      outlined: true,
      bgColor: Colors.transparent,
      textColor: context.colour.secondary,
    );
  }
}

class ErrorWidget extends StatelessWidget {
  final Object error;

  const ErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: context.colour.error, size: 20),
              const Gap(8),
              Text(
                context.loc.backupSettingsError,
                style: context.font.titleSmall?.copyWith(
                  color: context.colour.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            error.toString(),
            style: context.font.bodySmall?.copyWith(
              color: context.colour.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bip329LabelsButton extends StatelessWidget {
  const _Bip329LabelsButton();

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: context.loc.backupSettingsLabelsButton,
      onPressed: () => context.push(Bip329LabelsRouter.route.path),
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
    );
  }
}

class _RecoverBullSettingsButton extends StatelessWidget {
  const _RecoverBullSettingsButton();

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: context.loc.backupSettingsRecoverBullSettings,
      onPressed: () {
        context.pushNamed(
          RecoverBullRoute.recoverbullFlows.name,
          extra: RecoverBullFlowsExtra(
            flow: RecoverBullFlow.settings,
            vault: null,
          ),
        );
      },
      borderColor: context.colour.secondary,
      outlined: true,
      bgColor: Colors.transparent,
      textColor: context.colour.secondary,
    );
  }
}
