// ignore_for_file: avoid_print

import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/payjoin/listeners.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeWalletsSetupListener extends StatefulWidget {
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
  State<HomeWalletsSetupListener> createState() =>
      _HomeWalletsSetupListenerState();
}

class _HomeWalletsSetupListenerState extends State<HomeWalletsSetupListener> {
  @override
  void initState() {
    context.read<HomeBloc>().add(UpdatedNotifier(fromStart: true));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // return WalletBlocListeners(child: child);

    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
          previous.updated != current.updated && current.updated ||
          previous.wallets != current.wallets,
      listener: (context, state) {
        print('home wallets listener: ${state.wallets.length}');
        if (state.wallets.isEmpty) return;

        context.read<AppWalletBlocs>().updateWalletBlocs([
          for (final w in state.wallets) createWalletBloc(w),
        ]); // final walletBlocs = createWalletBlocs(state.tempwallets!);
        // context.read<HomeBloc>().updateWalletBlocs(
        //       createWalletBlocs(state.tempwallets!),
        //     );
        // context.read<HomeBloc>().clearWallets();
      },
      child: WalletBlocListeners(child: widget.child),
    );
  }
}

class WalletBlocListeners extends StatelessWidget {
  const WalletBlocListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((HomeBloc cubit) => cubit.state.wallets);
    if (wallets.isEmpty) return child;
    // .read<HomeBloc>().state.walletBlocs ?? [];

    // print each wallet id
    for (final wallet in wallets) {
      // print('wallet id: ${wallet.id}');
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
      // print(
      //   'mainWalletBloc.state.wallet!.mainWallet: ${mainWalletBloc.id}',
      // );
      walletChild = PayjoinLifecycleManager(
        wallet: mainWalletBloc,
        payjoinManager: locator<PayjoinManager>(),
        child: child,
      );
    }

    return walletChild;
    // return MultiBlocListener(
    //   listeners: [
    //     for (final w in wallets)
    //       BlocListener<WalletBloc, WalletState>(
    //         bloc: createWalletBloc(w),
    //         listenWhen: (previous, current) =>
    //             previous.wallet != current.wallet,
    //         listener: (context, state) {
    //           // context.read<HomeBloc>().updateWalletBloc(w);
    //         },
    //       ),
    //   ],
    //   child: walletChild,
    // );
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
    final walletBlocs = context.select((AppWalletBlocs x) => x.state);

    if (walletBlocs.isEmpty) return child;

    return MultiBlocListener(
      listeners: [
        for (final walletBloc in walletBlocs)
          BlocListener<WalletBloc, WalletState>(
            bloc: walletBloc,
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

  @override
  void onEvent(Bloc bloc, Object? event) {
    // locator<Logger>().log('$event', printToConsole: true);
    super.onEvent(bloc, event);
  }
}
