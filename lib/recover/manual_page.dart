import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/backup/google_drive.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover/bloc/cloud_cubit.dart';
import 'package:bb_mobile/recover/bloc/manual_cubit.dart';
import 'package:bb_mobile/recover/bloc/manual_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ManualRecoverPage extends StatelessWidget {
  const ManualRecoverPage({super.key, required this.wallets});

  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ManualCubit>(
      create: (_) => ManualCubit(
        filePicker: locator<FilePick>(),
        walletCreate: locator<WalletCreate>(),
        walletSensitiveCreate: locator<WalletSensitiveCreate>(),
        walletsStorageRepository: locator<WalletsStorageRepository>(),
        wallets: wallets,
        walletSensitiveStorage: locator<WalletSensitiveStorageRepository>(),
        bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
        lwkSensitiveCreate: locator<LWKSensitiveCreate>(),
      ),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          flexibleSpace: BBAppBar(
            text: 'Recover Backup',
            onBack: () => context.pop(),
            buttonKey: UIKeys.settingsBackButton,
          ),
        ),
        body: BlocListener<ManualCubit, ManualState>(
          listener: (context, state) async {
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                context.showToast(state.error),
              );
              context.read<ManualCubit>().clearError();
            }
            if (state.recovered) {
              ScaffoldMessenger.of(context).showSnackBar(
                context.showToast('Recovery completed'),
              );
              context.go('/home');
            }
          },
          child: BlocBuilder<ManualCubit, ManualState>(
            builder: (context, state) {
              final cubit = context.read<ManualCubit>();

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!state.recovered &&
                        state.backupId.isNotEmpty &&
                        state.backupKey.isEmpty)
                      ElevatedButton(
                        onPressed: () => context.push(
                          '/keychain-recover',
                          extra: state.backupId,
                        ),
                        child: const Text('Keychain'),
                      ),
                    if (!state.recovered && state.backupId.isNotEmpty)
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Backup Key'),
                        maxLength: 64,
                        onChanged: (value) => cubit.updateBackupKey(value),
                      ),
                    if (!state.recovered && state.backupKey.isEmpty)
                      Column(
                        children: [
                          BBButton.big(
                            label: 'Select file from FileSystem',
                            center: true,
                            onPressed: () => cubit.selectFileFromFs(),
                          ),
                          const Gap(20),
                          BlocProvider(
                            create: (context) => CloudCubit(
                              manager: locator<GoogleDriveBackupManager>(),
                            ),
                            child: BlocConsumer<CloudCubit, CloudState>(
                              listener: (context, state) {
                                if (state.error.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    context.showToast(state.error),
                                  );
                                  context.read<ManualCubit>().clearError();
                                }
                                if (state.toast.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    context.showToast(state.toast),
                                  );
                                  cubit.setSelectedBackup(
                                    state.selectedBackup.$1,
                                    state.selectedBackup.$2,
                                  );
                                }
                              },
                              builder: (context, state) {
                                return BBButton.big(
                                  loading: state.loading,
                                  label: 'Select file from Cloud',
                                  center: true,
                                  onPressed: () => {
                                    context.push(
                                      '/cloud-backup',
                                      extra: context.read<CloudCubit>(),
                                    ),
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    if (!state.recovered && state.backupKey.isNotEmpty)
                      BBButton.big(
                        label: 'Recover',
                        center: true,
                        onPressed: () => cubit.clickRecover(),
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

  void showModalPopup({
    required BuildContext context,
    required List<Widget> children,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext modalContext) => Container(
        height: 700,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
