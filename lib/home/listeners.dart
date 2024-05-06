import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeWalletsSetupListener extends StatelessWidget {
  const HomeWalletsSetupListener({super.key, required this.child});

  List<WalletBloc> createWalletBlocs(List<Wallet> tempwallets) {
    final walletCubits = [
      for (final w in tempwallets)
        WalletBloc(
          saveDir: w.getWalletStorageString(),
          walletSync: locator<WalletSync>(),
          walletsStorageRepository: locator<WalletsStorageRepository>(),
          walletBalance: locator<WalletBalance>(),
          walletAddress: locator<WalletAddress>(),
          networkCubit: locator<NetworkCubit>(),
          // swapBloc: locator<WatchTxsBloc>(),
          networkRepository: locator<NetworkRepository>(),
          walletsRepository: locator<WalletsRepository>(),
          walletTransactionn: locator<WalletTx>(),
          walletCreatee: locator<WalletCreate>(),
          wallet: w,
        ),
    ];
    return walletCubits;
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeCubit, HomeState>(
      listenWhen: (previous, current) =>
          previous.tempwallets != current.tempwallets,
      listener: (context, state) {
        if (state.tempwallets == null || state.tempwallets!.isEmpty) return;
        // final walletBlocs = createWalletBlocs(state.tempwallets!);
        context.read<HomeCubit>().updateWalletBlocs(
              createWalletBlocs(state.tempwallets!),
            );
        context.read<HomeCubit>().clearWallets();

        print('Wallets:  ' + state.tempwallets.toString());
      },
      child: WalletBlocListeners(child: child),
    );
  }
}

class WalletBlocListeners extends StatelessWidget {
  const WalletBlocListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wallets =
        context.select((HomeCubit cubit) => cubit.state.walletBlocs);
    if (wallets == null || wallets.isEmpty) return child;
    // .read<HomeCubit>().state.walletBlocs ?? [];
    return MultiBlocListener(
      listeners: [
        for (final w in wallets)
          BlocListener<WalletBloc, WalletState>(
            bloc: w,
            listenWhen: (previous, current) =>
                previous.wallet != current.wallet,
            listener: (context, state) {
              if (state.wallet == null) return;
              print('------Updated Wallet: ' + state.wallet!.id);
              context.read<HomeCubit>().updateWalletBloc(w);
            },
          ),
      ],
      child: child,
    );
  }
}

class BBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    locator<Logger>().log(
      error.toString() + '\n' + stackTrace.toString(),
      printToConsole: true,
    );
    super.onError(bloc, error, stackTrace);
  }
}
