import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/backup/google_drive.dart';
import 'package:bb_mobile/_pkg/backup/local.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/backup/bloc/cloud_cubit.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:bb_mobile/backup/bloc/manual_cubit.dart';
import 'package:bb_mobile/backup/bloc/manual_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ManualBackupPage extends StatefulWidget {
  const ManualBackupPage({super.key, required this.wallets});

  final List<Wallet> wallets;

  @override
  _TheBackupPageState createState() => _TheBackupPageState();
}

class _TheBackupPageState extends State<ManualBackupPage> {
  late final ManualCubit _backupCubit;

  @override
  void initState() {
    super.initState();
    _backupCubit = ManualCubit(
      wallets: widget.wallets,
      walletSensitiveStorage: locator<WalletSensitiveStorageRepository>(),
      manager: locator<FileSystemBackupManager>(),
    );
  }

  @override
  void dispose() {
    _backupCubit.clearAndClose();
    //TODO: clear cloud cubit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _backupCubit,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          flexibleSpace: BBAppBar(
            text: 'Backup',
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocListener<ManualCubit, ManualState>(
          listener: (context, state) {
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(context.showToast(state.error));

              context.read<ManualCubit>().clearError();
            }
            if (state.backupId.isNotEmpty && state.backupKey.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                context.showToast('Backup created successfully'),
              );
            }
          },
          child: BlocBuilder<ManualCubit, ManualState>(
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
                            value: state.selectedBackupOptions['mnemonic'] ??
                                false,
                            onChanged: () {
                              context
                                  .read<ManualCubit>()
                                  .toggleAllMnemonicAndPassphrase();
                            },
                          ),
                          const Gap(8),
                          BackupToggleItem(
                            title: 'Descriptors',
                            value: state.selectedBackupOptions['descriptors'] ??
                                false,
                            onChanged: () {
                              context.read<ManualCubit>().toggleDescriptors();
                            },
                          ),
                          const Gap(8),
                          BackupToggleItem(
                            title: 'Labels',
                            value:
                                state.selectedBackupOptions['labels'] ?? false,
                            onChanged: () {
                              context.read<ManualCubit>().toggleLabels();
                            },
                          ),
                          const Gap(8),
                          if (state.backupKey.isEmpty)
                            Center(
                              child: BBButton.big(
                                onPressed: () => context
                                    .read<ManualCubit>()
                                    .saveEncryptedBackup(),
                                label: "Generate Backup",
                              ),
                            ),
                          const Gap(20),
                          if (state.backupKey.isNotEmpty)
                            Column(
                              children: [
                                const BBText.bodyBold("Generated Backup Key"),
                                const Gap(10),
                                SelectableText(
                                  state.backupKey,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const Gap(20),
                                if (state.backupId.isNotEmpty)
                                  BBButton.big(
                                    onPressed: () => context.push(
                                      '/keychain-backup',
                                      extra: (state.backupKey, state.backupId),
                                    ),
                                    label: 'Save to Keychain',
                                  ),
                              ],
                            ),
                          const Gap(50),
                          if (state.backupPath.isNotEmpty)
                            BlocProvider(
                              create: (context) => CloudCubit(
                                manager: locator<GoogleDriveBackupManager>(),
                              ),
                              child: Center(
                                child: BlocConsumer<CloudCubit, CloudState>(
                                  listener: (context, cloudState) {
                                    if (cloudState.toast != '') {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        context.showToast(cloudState.toast),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        context.showToast(cloudState.error),
                                      );
                                    }
                                    if (!cloudState.loading) {
                                      context.read<CloudCubit>().clearToast();
                                      context.read<CloudCubit>().clearError();
                                    }
                                  },
                                  buildWhen: (p, q) => p.loading != q.loading,
                                  builder: (context, cloudState) {
                                    return BBButton.big(
                                      loading: cloudState.loading,
                                      onPressed: () {
                                        context.read<CloudCubit>().uploadBackup(
                                              fileSystemBackupPath:
                                                  state.backupPath,
                                            );
                                        // context.push(
                                        //   '/cloud-backup',
                                        //   extra: {
                                        //     'cubit': context.read<CloudCubit>(),
                                        //   },
                                        // );
                                      },
                                      label: "Save to Google Drive",
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
    return BlocListener<ManualCubit, ManualState>(
      listenWhen: (previous, current) =>
          previous.selectedBackupOptions != current.selectedBackupOptions,
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
