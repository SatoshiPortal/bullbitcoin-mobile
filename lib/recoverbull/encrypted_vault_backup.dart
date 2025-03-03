import 'dart:io';

import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/recoverbull/backup_settings.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_state.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const double _kSpacing = 15.0;

enum BackupProvider {
  googleDrive('Google Drive', 'Easy', Icons.add_to_drive_rounded),
  iCloud('Apple iCloud', 'Easy', CupertinoIcons.cloud_upload),
  custom('Custom location', 'Private', Icons.folder);

  final String title;
  final String description;
  final IconData icon;

  const BackupProvider(this.title, this.description, this.icon);
}

class EncryptedVaultBackupPage extends StatefulWidget {
  final String wallet;
  const EncryptedVaultBackupPage({super.key, required this.wallet});

  @override
  State<EncryptedVaultBackupPage> createState() =>
      _EncryptedVaultBackupPageState();
}

class _EncryptedVaultBackupPageState extends State<EncryptedVaultBackupPage> {
  late final BackupSettingsCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = createBackupSettingsCubit(walletId: widget.wallet);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _handleBackup(
    BuildContext context,
    BackupProvider provider,
  ) async {
    switch (provider) {
      case BackupProvider.googleDrive:
        await _cubit.saveGoogleDriveBackup();
      case BackupProvider.iCloud:
        debugPrint('iCloud backup');
      case BackupProvider.custom:
        _cubit.saveFileSystemBackup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
      ],
      child: BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
        listenWhen: (previous, current) =>
            previous.errorSavingBackups != current.errorSavingBackups ||
            previous.errorLoadingBackups != current.errorLoadingBackups ||
            (previous.savingBackups && !current.savingBackups),
        listener: (context, state) {
          if (state.errorSavingBackups.isNotEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(context.showToast(state.errorSavingBackups));
            _cubit.clearError();
            return;
          }

          if (state.errorLoadingBackups.isNotEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(context.showToast(state.errorLoadingBackups));
            _cubit.clearError();
            return;
          }
          if (!state.savingBackups &&
              state.backupFolderPath.isNotEmpty &&
              state.backupKey.isNotEmpty &&
              state.lastBackupAttempt != null &&
              state.errorSavingBackups.isEmpty) {
            context.push(
              '/wallet-settings/backup-settings/keychain',
              extra: (
                state.backupKey,
                {'id': state.backupId, 'salt': state.backupSalt},
                KeyChainPageState.enter.name.toLowerCase()
              ),
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
              flexibleSpace: BBAppBar(text: '', onBack: () => context.pop()),
            ),
            body: state.savingBackups
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const BBText.titleLarge(
                          'Choose vault location',
                          isBold: true,
                        ),
                        const Gap(15),
                        const _InfoSection(),
                        const Gap(20),
                        ...BackupProvider.values.map(
                          (provider) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: StorageOptionCard(
                              title: provider.title,
                              description: provider.description,
                              icon: Icon(provider.icon, size: 40),
                              onTap: () async =>
                                  await _handleBackup(context, provider),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BBText.bodySmall(
          textAlign: TextAlign.center,
          "Cloud storage providers like Google or Apple won't have access to your backup. They won't be able to guess the password. They can only access your Bitcoin in the unlikely event they collude with the key server.",
        ),
        const Gap(_kSpacing),
        _buildWhitepaperLink(context),
        const Gap(_kSpacing),
        Text(
          "It's up to you, you can store your vault anywhere you like.",
          textAlign: TextAlign.center,
          style: context.font.bodySmall!.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWhitepaperLink(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'To learn more about the tradeoffs and risks, read the',
            style: context.font.bodySmall!.copyWith(fontSize: 12),
          ),
          TextSpan(
            text: ' RecoverBull whitepaper',
            style: context.font.bodySmall!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {/* TODO */},
          ),
        ],
      ),
    );
  }
}

class StorageOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget icon;
  final VoidCallback onTap;

  const StorageOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: NewColours.lightGray.withAlpha(50),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: NewColours.lightGray.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: icon),
              Expanded(
                flex: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText.bodySmall(title),
                    const Gap(4),
                    RichText(
                      text: TextSpan(
                        text: description,
                        style: context.font.bodySmall!
                            .copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Icon(
                  Platform.isIOS
                      ? Icons.arrow_forward_ios
                      : Icons.arrow_forward,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EncryptedVaultRecoverPage extends StatefulWidget {
  const EncryptedVaultRecoverPage({
    super.key,
    this.wallet,
    this.canPop = true,
  });

  final String? wallet;
  final bool canPop;

  @override
  State<EncryptedVaultRecoverPage> createState() =>
      _EncryptedVaultRecoverPageState();
}

class _EncryptedVaultRecoverPageState extends State<EncryptedVaultRecoverPage> {
  late final BackupSettingsCubit _backupSettingsCubit;

  @override
  void initState() {
    super.initState();
    _backupSettingsCubit = createBackupSettingsCubit(walletId: widget.wallet);
  }

  @override
  void dispose() {
    _backupSettingsCubit.close();
    super.dispose();
  }

  Future<void> _handleRecover(
    BuildContext context,
    BackupProvider provider,
  ) async {
    switch (provider) {
      case BackupProvider.googleDrive:
        await _backupSettingsCubit.fetchGoogleDriveBackup();
      case BackupProvider.iCloud:
        debugPrint('iCloud backup');
      case BackupProvider.custom:
        _backupSettingsCubit.fetchFsBackup();
    }
  }

  Widget _buildContent(BuildContext context, BackupSettingsState state) {
    return Column(
      children: [
        const KeyServerWarnings(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const BBText.titleLarge('Where is your backup?', isBold: true),
              const Gap(20),
              ...BackupProvider.values.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StorageOptionCard(
                    title: provider.title,
                    description: provider.description,
                    icon: Icon(provider.icon, size: 40),
                    onTap: () => _handleRecover(context, provider),
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
    return BlocProvider.value(
      value: _backupSettingsCubit,
      child: BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
        listenWhen: (previous, current) =>
            previous.errorLoadingBackups != current.errorLoadingBackups ||
            previous.latestRecoveredBackup != current.latestRecoveredBackup,
        listener: (context, state) {
          if (state.errorLoadingBackups.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              context.showToast(state.errorLoadingBackups),
            );
            _backupSettingsCubit.clearError();
            return;
          }
          if (state.latestRecoveredBackup.isNotEmpty) {
            context.push(
              '/wallet-settings/backup-settings/recover-options/encrypted/info',
              extra: state.latestRecoveredBackup,
            );
            _backupSettingsCubit.clearError();
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
                onBack: () =>
                    widget.canPop ? context.pop() : context.go('/home'),
              ),
            ),
            body: state.loadingBackups
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context, state),
          );
        },
      ),
    );
  }
}

class RecoveredBackupInfoPage extends StatefulWidget {
  const RecoveredBackupInfoPage({
    super.key,
    required this.recoveredBackup,
  });

  final Map<String, dynamic> recoveredBackup;

  @override
  State<RecoveredBackupInfoPage> createState() =>
      _RecoveredBackupInfoPageState();
}

class _RecoveredBackupInfoPageState extends State<RecoveredBackupInfoPage> {
  late final BackupSettingsCubit _backupSettingsCubit;

  @override
  void initState() {
    super.initState();
    _backupSettingsCubit = createBackupSettingsCubit();
    context.read<KeychainCubit>().keyServerStatus();
  }

  @override
  void dispose() {
    _backupSettingsCubit.close();
    super.dispose();
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
    if (recoveryFile.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          flexibleSpace: BBAppBar(text: '', onBack: () => context.pop()),
        ),
        body: _buildErrorView(context),
      );
    } else if (recoveryFile['id'] == null ||
        recoveryFile['ciphertext'] == null ||
        recoveryFile['salt'] == null) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          flexibleSpace: BBAppBar(text: '', onBack: () => context.pop()),
        ),
        body: _buildErrorView(context),
      );
    }

    return BlocProvider.value(
      value: _backupSettingsCubit,
      child: BlocConsumer<BackupSettingsCubit, BackupSettingsState>(
        listenWhen: (previous, current) =>
            previous.errorLoadingBackups != current.errorLoadingBackups ||
            previous.loadingBackups != current.loadingBackups ||
            previous.loadedBackups != current.loadedBackups,
        listener: (context, state) {
          if (state.errorLoadingBackups.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              context.showToast(state.errorLoadingBackups),
            );
            _backupSettingsCubit.clearError();
            return;
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: true,
              flexibleSpace: BBAppBar(text: '', onBack: () => context.pop()),
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'We have your file',
                    style: context.font.titleLarge!.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Gap(20),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Backup ID:',
                          style: context.font.bodyMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '${recoveryFile['id']}',
                          style: context.font.bodyMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Created at:',
                          style: context.font.bodyMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ' ${DateFormat('MMM dd, yyyy HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(recoveryFile['created_at'] as int).toLocal())}',
                          style: context.font.bodyMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  Text(
                    "Now let's decrypt",
                    textAlign: TextAlign.center,
                    style: context.font.bodyMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: NewColours.lightGray,
                    ),
                  ),
                  const Gap(20),
                  BBButton.withColour(
                    leftIcon: Icons.arrow_forward_rounded,
                    label: 'Decrypt Backup',
                    disabled: state.loadingBackups,
                    onPressed: () => {
                      context.push(
                        '/wallet-settings/backup-settings/keychain',
                        extra: (
                          '',
                          widget.recoveredBackup,
                          KeyChainPageState.recovery.name.toLowerCase()
                        ),
                      ),
                    },
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
