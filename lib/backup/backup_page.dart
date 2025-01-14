import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/backup/bloc/backup_cubit.dart';
import 'package:bb_mobile/backup/bloc/backup_state.dart';
import 'package:bb_mobile/backup/bloc/cloud_cubit.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ManualBackupPage extends StatefulWidget {
  const ManualBackupPage({super.key, required this.wallets});

  final List<WalletBloc> wallets;

  @override
  _TheBackupPageState createState() => _TheBackupPageState();
}

class _TheBackupPageState extends State<ManualBackupPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<BackupCubit>(
      create: (_) => BackupCubit(
        wallets: widget.wallets,
        walletSensitiveStorage: locator<WalletSensitiveStorageRepository>(),
        fileStorage: locator<FileStorage>(),
      )..loadConfirmedBackups(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          flexibleSpace: BBAppBar(
            text: 'Backup',
            onBack: () => context.pop(),
          ),
        ),
        body: BlocListener<BackupCubit, BackupState>(
          listener: (context, state) {
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<BackupCubit>().clearError();
            }
            if (state.backupId.isNotEmpty && state.backupKey.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup completed'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: BlocBuilder<BackupCubit, BackupState>(
            builder: (context, state) {
              return state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BackupToggleItem(
                            title: 'Mnemonics & Passwords',
                            value: state.confirmedBackups['mnemonic'] ?? false,
                            onChanged: () {
                              context
                                  .read<BackupCubit>()
                                  .toggleAllMnemonicAndPassphrase();
                            },
                          ),
                          Gap(8),
                          BackupToggleItem(
                            title: 'Descriptors',
                            value:
                                state.confirmedBackups['descriptors'] ?? false,
                            onChanged: () {
                              context.read<BackupCubit>().toggleDescriptors();
                            },
                          ),
                          Gap(8),
                          BackupToggleItem(
                            title: 'Labels',
                            value: state.confirmedBackups['labels'] ?? false,
                            onChanged: () {
                              context.read<BackupCubit>().toggleLabels();
                            },
                          ),
                          Gap(8),
                          if (state.backupKey.isEmpty)
                            Center(child: _GenerateBackupButton()),
                          Gap(20),
                          if (state.backupKey.isNotEmpty)
                            Column(
                              children: [
                                const BBText.bodyBold("Generated Backup Key"),
                                Gap(10),
                                SelectableText(
                                  state.backupKey,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                Gap(20),
                                if (state.backupId.isNotEmpty)
                                  BBButton.big(
                                    onPressed: () => context.push(
                                      '/keychain-backup',
                                      extra: (state.backupKey, state.backupId),
                                    ),
                                    label: 'SAVE TO KEYCHAIN',
                                  ),
                              ],
                            ),
                          const Gap(50),
                          if (state.backupPath.isNotEmpty)
                            BlocProvider(
                              create: (context) => CloudCubit(
                                backupPath: state.backupPath,
                                backupName: state.backupName,
                              ),
                              child: Center(
                                child: BlocConsumer<CloudCubit, CloudState>(
                                  listener: (context, cloudState) {
                                    if (!cloudState.loading) {
                                      if (cloudState.error != '') {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              cloudState.error,
                                              textAlign: TextAlign.center,
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        context.read<CloudCubit>().clearError();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              cloudState.toast,
                                              textAlign: TextAlign.center,
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        context.read<CloudCubit>().clearToast();
                                      }
                                    }
                                  },
                                  builder: (context, cloudState) {
                                    return BBButton.big(
                                      loading: cloudState.loading,
                                      onPressed: () {
                                        context
                                            .read<CloudCubit>()
                                            .connectAndStoreBackup();
                                        context.push(
                                          '/cloud-backup',
                                          extra: context.read<CloudCubit>(),
                                        );
                                      },
                                      label: "SAVE TO GOOGLE DRIVE",
                                    );
                                  },
                                ),
                              ),
                            ),
                          const Gap(10),
                        ],
                      ),
                    );
            },
          ),
        ),
      ),
    );
  }
}

class BackupToggleItem extends StatelessWidget {
  final String title;
  final bool value;
  final VoidCallback onChanged;
  const BackupToggleItem({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupCubit, BackupState>(
      listenWhen: (previous, current) =>
          previous.confirmedBackups != current.confirmedBackups,
      listener: (context, state) {},
      child: Row(
        children: [
          BBText.body(
            title,
          ),
          const Spacer(),
          BBSwitch(
            // key: UIKeys.settingsBackupToggleSwitch,//TODO; Add switch key
            value: value,
            onChanged: (e) {
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _GenerateBackupButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupCubit, BackupState>(
      builder: (context, state) {
        final mnemonicConfirmed = state.confirmedBackups['mnemonic'] ?? false;

        return Center(
          child: BBButton.big(
            onPressed: () {
              if (!mnemonicConfirmed) {
                _showConfirmDialog(context);
              } else {
                context.read<BackupCubit>().writeEncryptedBackup();
              }
            },
            label: "GENERATE BACKUP",
          ),
        );
      },
    );
  }
}

void _showConfirmDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const BBText.body('Confirm New Mnemonic'),
        content: const BBText.bodySmall(
          'You have not confirmed your mnemonic. Generating a backup now will create a new mnemonic for the backup key. Are you sure you want to proceed?',
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          TextButton(
            child: const Text('Confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<BackupCubit>().writeEncryptedBackup();
            },
          ),
        ],
      );
    },
  );
}
