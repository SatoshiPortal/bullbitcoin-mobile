import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
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
          listenWhen: (previous, current) => previous.wallet != current.wallet,
          listener: (context, state) async {
            if (!state.deleted) return;

            // home.updateSelectedWallet(walletBloc);

            await context.read<HomeCubit>().getWalletsFromStorage();
            context.pop();
          },
        ),
        BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) =>
              previous.savedName != current.savedName,
          listener: (context, state) {
            if (state.savedName)
              FocusScope.of(context).requestFocus(FocusNode());
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
    return BlocListener<WalletSettingsCubit, WalletSettingsState>(
      listenWhen: (previous, current) =>
          previous.backupTested != current.backupTested,
      listener: (context, state) {
        if (!state.backupTested) return;

        final walletBloc = context
            .read<HomeCubit>()
            .state
            .findWalletBlocWithSameFngr(state.wallet);
        if (walletBloc == null) return;

        final w = walletBloc.state.wallet!.copyWith(
          backupTested: true,
          lastBackupTested: DateTime.now(),
        );

        walletBloc.add(
          UpdateWallet(
            w,
            updateTypes: [
              UpdateWalletTypes.settings,
            ],
          ),
        );
      },
      child: child,
    );
  }
}
