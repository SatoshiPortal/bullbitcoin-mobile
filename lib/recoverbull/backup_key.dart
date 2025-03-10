import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/recoverbull/backup_settings.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_state.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_state.dart';
import 'package:bb_mobile/recoverbull/encrypted_vault_backup.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:recoverbull/recoverbull.dart';

class BackupKeyPage extends StatefulWidget {
  final String wallet;
  const BackupKeyPage({super.key, required this.wallet});

  @override
  State<BackupKeyPage> createState() => _BackupKeyPageState();
}

class _BackupKeyPageState extends State<BackupKeyPage> {
  late final BackupSettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = createBackupSettingsCubit(walletId: widget.wallet);
    _initializeKeyServer();
  }

  void _initializeKeyServer() {
    context.read<KeychainCubit>().keyServerStatus();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _handleRecover(BackupProvider provider) async {
    await provider.handleRecover(_cubit);
  }

  Widget _buildLoadingState() =>
      const Center(child: CircularProgressIndicator());

  Widget _buildContent(BuildContext context, BackupSettingsState state) {
    return Column(
      children: [
        const KeyServerWarnings(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const BBText.titleLarge(
                'Where is your latest backup?',
                isBold: true,
              ),
              const Gap(20),
              ...BackupProvider.values.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StorageOptionCard(
                    title: provider.title,
                    description: provider.description,
                    icon: Icon(provider.icon, size: 40),
                    onTap: () => _handleRecover(provider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KeychainCubit, KeychainState>(
      listener: (context, state) {
        if (!state.keyServerUp) {
          ScaffoldMessenger.of(context).showSnackBar(
            context.showToast(state.error),
          );
        }
      },
      listenWhen: (previous, current) =>
          previous.keyServerUp != current.keyServerUp ||
          current.loading != previous.loading,
      child: BlocProvider.value(
        value: _cubit,
        child: BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
          listenWhen: (previous, current) =>
              previous.errorLoadingBackups != current.errorLoadingBackups ||
              previous.latestRecoveredBackup != current.latestRecoveredBackup,
          listener: (context, state) {
            if (state.errorLoadingBackups.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                context.showToast(state.errorLoadingBackups),
              );
              _cubit.clearError();
              return;
            }
            if (state.latestRecoveredBackup != null) {
              context.push(
                '/wallet-settings/backup-settings/key/options',
                extra: ('', state.latestRecoveredBackup),
              );
              _cubit.clearError();
            }
          },
          builder: (context, state) {
            return Scaffold(
              appBar: AppBar(
                elevation: 0,
                automaticallyImplyLeading: false,
                centerTitle: true,
                flexibleSpace: BBAppBar(
                  text: '',
                  onBack: () => context.pop(),
                ),
              ),
              body: state.loadingBackups
                  ? _buildLoadingState()
                  : _buildContent(context, state),
            );
          },
        ),
      ),
    );
  }
}

class BackupKeyOptionsPage extends StatefulWidget {
  const BackupKeyOptionsPage({
    super.key,
    this.recoveredBackup,
    required this.backupKey,
  });

  final BullBackup? recoveredBackup;
  final String backupKey;

  @override
  State<BackupKeyOptionsPage> createState() => _BackupKeyInfoPage();
}

class _BackupKeyInfoPage extends State<BackupKeyOptionsPage> {
  late final BackupSettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = createBackupSettingsCubit();
    _initializeKeyServer();
  }

  void _initializeKeyServer() {
    context.read<KeychainCubit>().keyServerStatus();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _handleBackupAction(BuildContext context) async {
    if (widget.backupKey.isNotEmpty) {
      _showBackupKeyDialog(context, widget.backupKey);
    } else {
      _navigateToKeychain(context);
    }
  }

  void _navigateToKeychain(BuildContext context) {
    context.push(
      '/wallet-settings/backup-settings/keychain',
      extra: (
        '',
        widget.recoveredBackup,
        KeyChainPageState.download.name.toLowerCase(),
      ),
    );
  }

  void _showBackupKeyDialog(BuildContext context, String backupKey) {
    showDialog(
      context: context,
      builder: (context) => _BackupKeyDialog(backupKey: backupKey),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ERROR',
            style: context.font.titleLarge!.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const Gap(16),
          const BBText.title('This is not a backup file', isBold: true),
          const Gap(24),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              backgroundColor: context.colour.shadow,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Try again',
                  style: context.font.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Gap(8),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recoveryFile = widget.recoveredBackup;
    if (recoveryFile == null) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          flexibleSpace: BBAppBar(text: '', onBack: () => context.go('/home')),
        ),
        body: _buildErrorView(context),
      );
    }

    return MultiBlocProvider(
      providers: [BlocProvider.value(value: _cubit)],
      child: Builder(
        builder: (context) {
          return BlocBuilder<KeychainCubit, KeychainState>(
            builder: (context, keyState) {
              return BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
                listenWhen: (previous, current) =>
                    previous.backupKey != current.backupKey ||
                    previous.loadingBackups != current.loadingBackups,
                listener: (context, state) {
                  if (state.errorLoadingBackups.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      context.showToast(state.errorLoadingBackups),
                    );
                    context.read<BackupSettingsCubit>().clearError();
                    return;
                  }
                  if (!state.errorLoadingBackups.isNotEmpty &&
                      !state.loadingBackups &&
                      state.backupKey.isNotEmpty) {
                    _showBackupKeyDialog(context, state.backupKey);
                    context.read<BackupSettingsCubit>().clearError();
                  }
                },
                builder: (context, state) {
                  return Scaffold(
                    appBar: AppBar(
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      centerTitle: true,
                      flexibleSpace: BBAppBar(
                        text: '',
                        onBack: () => context.go('/home'),
                      ),
                    ),
                    body: keyState.loading
                        ? const Center(child: CircularProgressIndicator())
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Latest available backup',
                                  style: context.font.titleLarge!
                                      .copyWith(fontWeight: FontWeight.w900),
                                ),
                                const Gap(20),
                                _buildInfoText(
                                  context,
                                  'Backup ID:',
                                  recoveryFile.id,
                                ),
                                const Gap(8),
                                _buildInfoText(
                                  context,
                                  'Created at:',
                                  DateFormat('MMM dd, yyyy HH:mm:ss').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      recoveryFile.createdAt,
                                    ).toLocal(),
                                  ),
                                ),
                                const Gap(20),
                                BBButton.withColour(
                                    fillWidth: true,
                                    label: 'Show Backup Key',
                                    leftIcon: widget.backupKey.isNotEmpty
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.cloud_download_fill,
                                    onPressed: () => context
                                        .read<BackupSettingsCubit>()
                                        .recoverBackupKeyFromMnemonic(
                                          widget.recoveredBackup?.path,
                                        )),
                                const Gap(10),
                                BBButton.withColour(
                                  fillWidth: true,
                                  label: 'Delete Backup Key',
                                  disabled: !keyState.keyServerUp,
                                  leftIcon: CupertinoIcons.delete_right,
                                  onPressed: () => context.push(
                                    '/wallet-settings/backup-settings/keychain',
                                    extra: (
                                      '',
                                      widget.recoveredBackup,
                                      KeyChainPageState.delete.name
                                          .toLowerCase()
                                    ),
                                  ),
                                ),
                                const Gap(10),
                              ],
                            ),
                          ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoText(BuildContext context, String label, String value) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style:
                context.font.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style:
                context.font.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BackupKeyDialog extends StatelessWidget {
  final String backupKey;

  const _BackupKeyDialog({required this.backupKey});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colour.primaryContainer,
      title: const BBText.title('Backup key', isBold: true),
      content: Row(
        children: [
          Expanded(
            child: Text(
              backupKey,
              style:
                  context.font.bodySmall!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(context),
            icon: Icon(Icons.copy, color: context.colour.primary),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: backupKey));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      context.showToast('Copied to clipboard'),
    );
  }
}
