import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_key_warning.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/bottom_sheet/x.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    bool isBottomSheetShown = false;

    return BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
      listener: (context, state) {
        if (state.downloadedBackupFile != null) {
          Clipboard.setData(ClipboardData(text: state.downloadedBackupFile!));
          log.info('Vault exported and copied to clipboard');
          context.read<BackupSettingsCubit>().clearDownloadedData();
        }
        if (state.error != null) {
          log.severe('Export failed: ${state.error}');
          if (state.error != 'Local backup key derivation failed.') {
            // Navigate to Key Server flow, require PIN
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
            context.read<BackupSettingsCubit>().clearDownloadedData();
          }
        }
        if (state.derivedBackupKey != null && !isBottomSheetShown) {
          isBottomSheetShown = true;
          BlurredBottomSheet.show<void>(
            context: context,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: context.colour.onPrimary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        const Gap(20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Gap(24),
                            BBText(
                              'Backup Key',
                              style: context.font.headlineMedium?.copyWith(
                                color: context.colour.secondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                                context
                                    .read<BackupSettingsCubit>()
                                    .clearDownloadedData();
                                isBottomSheetShown = false;
                              },
                              child: Icon(
                                Icons.close,
                                color: context.colour.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.colour.secondary.withValues(
                                  alpha: 0.1,
                                ),
                                border: Border.all(
                                  color: context.colour.secondary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                state.derivedBackupKey!,
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.colour.secondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const Gap(32),
                            SizedBox(
                              width: double.infinity,
                              child: BBButton.big(
                                label: 'Copy to Clipboard',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: state.derivedBackupKey!,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                  context
                                      .read<BackupSettingsCubit>()
                                      .clearDownloadedData();
                                  isBottomSheetShown = false;
                                },
                                bgColor: context.colour.secondary,
                                textStyle: context.font.headlineLarge,
                                textColor: context.colour.onPrimary,
                              ),
                            ),
                            const Gap(30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).then((_) {
            isBottomSheetShown = false;
          });
        }
      },
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
                  if (state.lastEncryptedBackup != null && isSuperuser) ...[
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
                  if (state.lastEncryptedBackup != null && isSuperuser)
                    const _KeyServerStatusWidget(),
                ],
              ),
            ),
          ),
        );
      },
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
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    return BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              label: 'Physical Backup',
              isTested: state.isDefaultPhysicalBackupTested,
            ),
            if (isSuperuser) ...[
              const Gap(15),
              _StatusRow(
                label: 'Encrypted Vault',
                isTested: state.isDefaultEncryptedBackupTested,
              ),
            ],
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
                  : 'View Backup Key',
          onPressed:
              state.status == BackupSettingsStatus.viewingKey
                  ? () {}
                  : () async {
                    final confirmed = await BackupKeyWarningBottomSheet.show(
                      context,
                    );
                    if (confirmed == true) {
                      try {
                        if (!context.mounted) return;
                        final cubit = context.read<BackupSettingsCubit>();
                        final filePath = await cubit.selectBackupFile();
                        if (filePath != null) {
                          final fileContent = await cubit.readBackupFile(
                            filePath,
                          );
                          await cubit.viewVaultKey(fileContent);
                        }
                      } catch (e) {
                        log.severe('Failed to view backup key: $e');
                      }
                    }
                  },
          bgColor: Colors.transparent,
          textColor: context.colour.secondary,
          borderColor: context.colour.secondary,
          outlined: true,
        );
      },
    );
  }
}
