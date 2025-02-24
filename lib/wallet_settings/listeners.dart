import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletSettingsListeners extends StatelessWidget {
  const WalletSettingsListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) =>
              previous.deleted != current.deleted,
          listener: (context, state) async {
            if (!state.deleted) return;

            // home.updateSelectedWallet(walletBloc);

            // await context.read<AppWalletsRepository>().getWalletsFromStorage();
            context.read<HomeBloc>().add(LoadWalletsFromStorage());
            if (!context.mounted) return;
            context.pop();
          },
        ),
        BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) =>
              previous.savedName != current.savedName,
          listener: (context, state) {
            if (state.savedName) {
              FocusScope.of(context).requestFocus(FocusNode());
            }
          },
        ),
      ],
      child: child,
    );
  }
}

class TestBackupListener extends StatelessWidget {
  const TestBackupListener({super.key, required this.child});

  final Widget child;
  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (previous, current) =>
          previous.backupTested != current.backupTested,
      listener: (context, state) {
        if (!state.backupTested) return;

        final wallet = context.read<WalletBloc>().state.wallet;

        final walletService = context
            .read<AppWalletsRepository>()
            .findWalletServiceWithSameFngr(wallet);
        // .findWalletBlocWithSameFngr(state.wallet);
        if (walletService == null) return;

        final w = walletService.wallet.copyWith(
          physicalBackupTested: true,
          lastPhysicalBackupTested: DateTime.now(),
        );

        walletService.updateWallet(
          w,
          updateTypes: [
            UpdateWalletTypes.settings,
          ],
        );

        // walletService.add(
        //   UpdateWallet(
        //     w,
        //     updateTypes: [
        //       UpdateWalletTypes.settings,
        //     ],
        //   ),
        // );
      },
      child: child,
    );
  }
}
