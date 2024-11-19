import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/backup/bloc/cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TheBackupPage extends StatefulWidget {
  const TheBackupPage({
    super.key,
    required this.walletBloc,
  });

  final WalletBloc walletBloc;

  @override
  _TheBackupPageState createState() => _TheBackupPageState();
}

class _TheBackupPageState extends State<TheBackupPage> {
  bool hasMnemonic = false;
  bool hasPassphrases = false;
  bool hasDescriptors = false;
  String backupKey = '';

  @override
  Widget build(BuildContext context) {
    final backupCubit = BackupCubit(
      walletBloc: widget.walletBloc,
      walletSensitiveStorage: locator<WalletSensitiveStorageRepository>(),
      fileStorage: locator<FileStorage>(),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.walletBloc),
        BlocProvider.value(value: backupCubit),
      ],
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Backup',
            onBack: () => context.pop(),
          ),
        ),
        body: FutureBuilder<Backup>(
          future: backupCubit.loadBackupData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              final backup = snapshot.data!;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (backup.mnemonic.isNotEmpty && backupKey.isEmpty)
                      CheckboxListTile(
                        title: const BBText.body('Mnemonic'),
                        value: hasMnemonic,
                        tileColor: Colors.amber,
                        onChanged: (value) {
                          setState(() => hasMnemonic = value ?? false);
                        },
                      ),
                    if (backup.passphrases.isNotEmpty && backupKey.isEmpty)
                      CheckboxListTile(
                        title: const BBText.body('Passphrases'),
                        value: hasPassphrases,
                        tileColor: Colors.amber,
                        onChanged: (value) {
                          setState(() => hasPassphrases = value ?? false);
                        },
                      ),
                    if (backup.descriptors.isNotEmpty && backupKey.isEmpty)
                      CheckboxListTile(
                        title: const BBText.body('Descriptors'),
                        value: hasDescriptors,
                        tileColor: Colors.amber,
                        onChanged: (value) {
                          setState(() => hasDescriptors = value ?? false);
                        },
                      ),
                    const SizedBox(height: 20),
                    if (backupKey.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Backup Key:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              backupKey,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (backupKey.isEmpty)
                      ElevatedButton(
                        onPressed: () async {
                          final (secret, error) =
                              await backupCubit.writeEncryptedBackup(
                            hasMnemonic: hasMnemonic,
                            hasPassphrases: hasPassphrases,
                            hasDescriptors: hasDescriptors,
                          );
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              context.showToast(error.toString()),
                            );
                          }

                          if (secret != null) backupKey = secret;
                          setState(() {});
                        },
                        child: const Text('Encrypt'),
                      ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
