import 'dart:io';

import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
    _cubit = createBackupSettingsCubit(widget.wallet);
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
        _cubit.saveEncryptedBackup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
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
              extra: (state.backupId, (state.backupKey, state.backupSalt)),
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
                            child: _StorageOptionCard(
                              title: provider.title,
                              description: provider.description,
                              icon: Icon(provider.icon, size: 40),
                              onTap: () => _handleBackup(context, provider),
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

class _StorageOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget icon;
  final VoidCallback onTap;

  const _StorageOptionCard({
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
