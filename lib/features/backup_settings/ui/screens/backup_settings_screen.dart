import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_key_warning.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
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
    return MultiBlocListener(
      listeners: [
        BlocListener<BackupSettingsCubit, BackupSettingsState>(
          listenWhen:
              (previous, current) =>
                  previous.downloadedBackupFile !=
                      current.downloadedBackupFile &&
                  current.downloadedBackupFile != null,
          listener: (context, state) {
            Clipboard.setData(ClipboardData(text: state.downloadedBackupFile!));
            log.info('Vault exported and copied to clipboard');
            context.read<BackupSettingsCubit>().clearDownloadedData();
          },
        ),
        BlocListener<BackupSettingsCubit, BackupSettingsState>(
          listenWhen:
              (previous, current) =>
                  previous.error != current.error && current.error != null,
          listener: (context, state) {
            if (state.derivedBackupKey == null &&
                state.error is BackupKeyDerivationFailedError) {
              context.pushNamed(
                KeyServerRoute.keyServerFlow.name,
                extra: (
                  state.downloadedBackupFile ?? '',
                  CurrentKeyServerFlow.recovery.name,
                  false,
                ),
              );
              context.read<BackupSettingsCubit>().clearDownloadedData();
            } else {
              log.severe('Backup settings error: ${state.error}');
            }
          },
        ),
      ],
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(20),
                    const _BackupTestStatusWidget(),
                    const Gap(30),
                    if (state.lastEncryptedBackup != null) ...[
                      const _ExportVaultButton(),
                      const Gap(10),
                      _ViewVaultKeyButton(),
                      const Gap(10),
                    ],
                    if (state.lastEncryptedBackup != null ||
                        state.lastPhysicalBackup != null)
                      const _TestBackupButton(),
                    const Gap(5),
                    const _StartBackupButton(),

                    const Spacer(),
                    if (state.lastEncryptedBackup != null)
                      const _KeyServerStatusWidget(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KeyServerStatusWidget extends StatelessWidget {
  const _KeyServerStatusWidget();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<KeyServerCubit>()..checkConnection(),
      child: BlocBuilder<KeyServerCubit, KeyServerState>(
        builder: (context, state) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child:
                  state.torStatus == TorStatus.connecting
                      ? Gif(
                        image: AssetImage(Assets.animations.cubesLoading.path),
                        autostart: Autostart.loop,
                        height: 56,
                        width: 56,
                      )
                      : RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Key Server ',
                              style: context.font.labelLarge?.copyWith(
                                fontSize: 12,
                                color: context.colour.secondary,
                              ),
                            ),

                            WidgetSpan(
                              child: Icon(
                                Icons.circle,
                                size: 12,
                                color:
                                    state.torStatus == TorStatus.online
                                        ? context.colour.inverseSurface
                                        : context.colour.error,
                              ),
                            ),
                          ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              label: 'Physical Backup',
              isTested: state.isDefaultPhysicalBackupTested,
            ),
            const Gap(15),
            _StatusRow(
              label: 'Encrypted Vault',
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
          isTested ? 'Tested' : 'Not Tested',
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
      label: 'Test Backup',
      onPressed:
          () => context.pushNamed(
            BackupSettingsSubroute.testbackupOptions.name,
            extra: false,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: BBButton.big(
        label: 'Start Backup',
        onPressed:
            () => context.pushNamed(BackupSettingsSubroute.backupOptions.name),
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}

class _ExportVaultButton extends StatelessWidget {
  const _ExportVaultButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      builder: (context, state) {
        return BBButton.big(
          label:
              state.status == BackupSettingsStatus.exporting
                  ? 'Exporting...'
                  : 'Export Vault',
          onPressed:
              state.status == BackupSettingsStatus.exporting
                  ? () {}
                  : () => context.read<BackupSettingsCubit>().exportVault(),
          bgColor: Colors.transparent,
          disabled: state.status == BackupSettingsStatus.exporting,
          textColor: context.colour.secondary,
          borderColor: context.colour.secondary,
          outlined: true,
        );
      },
    );
  }
}

class _ViewVaultKeyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      builder: (context, state) {
        return BBButton.big(
          label:
              state.status == BackupSettingsStatus.viewingKey
                  ? 'Revealing...'
                  : 'View Vault Key',
          onPressed:
              state.status == BackupSettingsStatus.viewingKey
                  ? () {}
                  : () async {
                    final confirmed = await BackupKeyWarningBottomSheet.show(
                      context,
                    );
                    if (confirmed == true) {
                      if (!context.mounted) return;
                      // Navigate to provider selection screen
                      await context.pushNamed(
                        BackupSettingsSubroute.chooseVaultProvider.name,
                      );
                    }
                  },
          bgColor: Colors.transparent,
          disabled: state.status == BackupSettingsStatus.viewingKey,
          textColor: context.colour.secondary,
          borderColor: context.colour.secondary,
          outlined: true,
        );
      },
    );
  }
}
