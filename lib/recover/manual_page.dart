import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover/bloc/manual_cubit.dart';
import 'package:bb_mobile/recover/bloc/manual_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ManualRecoverPage extends StatelessWidget {
  const ManualRecoverPage({super.key, required this.wallets});

  final List<WalletBloc> wallets;

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
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<ManualCubit>().clearError();
            }
            if (state.recovered) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recovery completed'),
                  backgroundColor: Colors.green,
                ),
              );
              await locator<HomeCubit>().getWalletsFromStorage();
              context.go('/home');
            }
          },
          child: BlocBuilder<ManualCubit, ManualState>(
            builder: (context, state) {
              final cubit = context.read<ManualCubit>();

              return Column(
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
                    BBButton.big(
                      label: 'Select File',
                      center: true,
                      onPressed: () => cubit.selectFile(),
                    ),
                  if (!state.recovered && state.backupKey.isNotEmpty)
                    BBButton.big(
                      label: 'Recover',
                      center: true,
                      onPressed: () => cubit.clickRecover(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
