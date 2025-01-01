import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/payjoin/listeners.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeWalletsSetupListener extends StatelessWidget {
  const HomeWalletsSetupListener({super.key, required this.child});

  // List<WalletBloc> createWalletBlocs(List<Wallet> tempwallets) {
  //   final walletCubits = [
  //     for (final w in tempwallets)
  //       WalletBloc(
  //         saveDir: w.getWalletStorageString(),
  //         walletSync: locator<WalletSync>(),
  //         walletsStorageRepository: locator<WalletsStorageRepository>(),
  //         walletBalance: locator<WalletBalance>(),
  //         walletAddress: locator<WalletAddress>(),
  //         // networkCubit: locator<NetworkCubit>(),
  //         // swapBloc: locator<WatchTxsBloc>(),
  //         networkRepository: locator<InternalNetworkRepository>(),
  //         walletsRepository: locator<InternalWalletsRepository>(),
  //         walletTransactionn: locator<WalletTx>(),
  //         walletCreatee: locator<WalletCreate>(),
  //         appWalletsRepository: locator<AppWalletsRepository>(),
  //         wallet: w,
  //       ),
  //   ];
  //   return walletCubits;
  // }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WalletBlocListeners(child: child);
    // return BlocListener<HomeBloc, HomeState>(
    //   listenWhen: (previous, current) =>
    //       previous.wallets != current.wallets,
    //   listener: (context, state) {
    //     if (state.wallets == null || state.wallets!.isEmpty) return;
    //     // final walletBlocs = createWalletBlocs(state.tempwallets!);
    //     context.read<HomeBloc>().updateWalletBlocs(
    //           createWalletBlocs(state.tempwallets!),
    //         );
    //     context.read<HomeBloc>().clearWallets();
    //   },
    //   child: WalletBlocListeners(child: child),
    // );
  }
}

class WalletBlocListeners extends StatelessWidget {
  const WalletBlocListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((HomeBloc cubit) => cubit.state.wallets);
    if (wallets == null || wallets.isEmpty) return child;
    // .read<HomeBloc>().state.walletBlocs ?? [];

    // print each wallet id
    for (final wallet in wallets) {
      print('wallet id: ${wallet.id}');
    }
    final mainWalletBloc = wallets.firstWhere(
      (bloc) =>
          bloc.mainWallet == true &&
          !bloc.watchOnly() &&
          bloc.isSecure() &&
          bloc.isActive(),
      orElse: () =>
          wallets.first, // Return first wallet if no main wallet found
    );

    var walletChild = child;
    if (mainWalletBloc.mainWallet == true &&
        !mainWalletBloc.watchOnly() &&
        mainWalletBloc.isSecure()) {
      print(
        'mainWalletBloc.state.wallet!.mainWallet: ${mainWalletBloc.id}',
      );
      walletChild = PayjoinLifecycleManager(
        wallet: mainWalletBloc,
        payjoinManager: locator<PayjoinManager>(),
        child: child,
      );
    }

    return MultiBlocListener(
      listeners: [
        for (final w in wallets)
          BlocListener<WalletBloc, WalletState>(
            bloc: createWalletBloc(w),
            listenWhen: (previous, current) =>
                previous.wallet != current.wallet,
            listener: (context, state) {
              // context.read<HomeBloc>().updateWalletBloc(w);
            },
          ),
      ],
      child: walletChild,
    );
  }
}

class HomeLoadingEvent {}

class SetLoading extends HomeLoadingEvent {
  SetLoading(this.id, this.loading);
  final String id;
  final bool loading;
}

class HomeLoadingCubit extends Bloc<HomeLoadingEvent, Map<String, bool>> {
  HomeLoadingCubit() : super({}) {
    on<SetLoading>(
      (event, emit) {
        final map = state;
        map[event.id] = event.loading;
        emit({});
        emit(map);
      },
      transformer: droppable(),
    );
  }
}

class HomeWalletLoadingListeners extends StatelessWidget {
  const HomeWalletLoadingListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final wallets =
        context.select((HomeBloc x) => x.state.walletsFromNetwork(network));

    if (wallets.isEmpty) return child;

    return MultiBlocListener(
      listeners: [
        for (final wallet in wallets)
          BlocListener<WalletBloc, WalletState>(
            bloc: createWalletBloc(wallet),
            listenWhen: (previous, current) =>
                previous.syncing != current.syncing,
            listener: (context, state) {
              if (state.syncing) {
                context
                    .read<HomeLoadingCubit>()
                    .add(SetLoading(state.wallet.id, true));
              } else {
                context
                    .read<HomeLoadingCubit>()
                    .add(SetLoading(state.wallet.id, false));
              }
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
    locator<Logger>().log('$error\n$stackTrace', printToConsole: true);
    super.onError(bloc, error, stackTrace);
  }
}
