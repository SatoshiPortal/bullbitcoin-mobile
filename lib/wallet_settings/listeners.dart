import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
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
