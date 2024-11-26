import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/backup/bloc/backup_cubit.dart';
import 'package:bb_mobile/backup/bloc/backup_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TheBackupPage extends StatefulWidget {
  const TheBackupPage({super.key, required this.wallets});

  final List<WalletBloc> wallets;

  @override
  _TheBackupPageState createState() => _TheBackupPageState();
}

class _TheBackupPageState extends State<TheBackupPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<BackupCubit>(
      create: (_) => BackupCubit(
        wallets: widget.wallets,
        walletSensitiveStorage: locator<WalletSensitiveStorageRepository>(),
        fileStorage: locator<FileStorage>(),
      )..loadBackupData(),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          flexibleSpace: BBAppBar(
            text: 'Recover Backup',
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.backupKey.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.amber, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Backup Key:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  SelectableText(
                                    state.backupKey,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (state.backupId.isNotEmpty)
                                    ElevatedButton(
                                      onPressed: () => context.push(
                                        '/keychain-backup',
                                        extra: (
                                          state.backupKey,
                                          state.backupId
                                        ),
                                      ),
                                      child: const Text('Keychain'),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (state.backupKey.isEmpty)
                            ElevatedButton(
                              onPressed: context
                                  .read<BackupCubit>()
                                  .writeEncryptedBackup,
                              child: const Text('Backup'),
                            ),
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
