import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required WalletsStorageRepository walletsStorageRepository,
  })  : _walletsStorageRepository = walletsStorageRepository,
        super(const HomeState());

  final WalletsStorageRepository _walletsStorageRepository;

  Future<void> getWalletsFromStorage() async {
    emit(state.copyWith(loadingWallets: true));

    final (wallets, err) = await _walletsStorageRepository.readAllWallets();
    if (err != null && err.toString() != 'No Key') {
      emit(state.copyWith(loadingWallets: false));
      return;
    }

    if (wallets == null) {
      emit(state.copyWith(loadingWallets: false));
      return;
    }

    // final blocs = state.createWalletBlocs(wallets);
    await Future.delayed(const Duration(milliseconds: 300));

    // print('Wallets: $wallets');

    emit(
      state.copyWith(
        tempwallets: wallets,
        // walletBlocs: blocs,
        walletBlocs: null,
        loadingWallets: false,
      ),
    );

    // if (err.toString() == 'No Key')
    //   createWalletCubit.createMne(
    //     fromHome: true,
    //   );
  }

  void clearWallets() => emit(state.copyWith(tempwallets: null));

  void updateErrDeepLink(String err) async {
    emit(state.copyWith(errDeepLinking: err));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(errDeepLinking: ''));
  }

  // void updateWalletBloc(WalletBloc bloc) {
  //   final walletBlocs = state.walletBlocs != null
  //       ? state.walletBlocs!.toList()
  //       : <WalletBloc>[];
  //   final idx = walletBlocs
  //       .indexWhere((wB) => wB.state.wallet!.id == bloc.state.wallet!.id);
  //   walletBlocs[idx] = bloc;

  //   emit(state.copyWith(walletBlocs: walletBlocs));
  // }

  void updateWalletBlocs(List<WalletBloc> blocs) =>
      emit(state.copyWith(walletBlocs: blocs));

  void updateWalletBloc(WalletBloc bloc) {
    final walletBlocs = state.walletBlocs != null
        ? state.walletBlocs!.toList()
        : <WalletBloc>[];
    final idx = walletBlocs
        .indexWhere((wB) => wB.state.wallet!.id == bloc.state.wallet!.id);
    walletBlocs[idx] = bloc;

    emit(state.copyWith(walletBlocs: walletBlocs));

    updatedNotifier();
  }

  void updatedNotifier() async {
    emit(state.copyWith(updated: true));
    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(updated: false));
  }

  void loadWalletsForNetwork(BBNetwork network) {
    print('::::::1');
    final blocs = state.walletBlocsFromNetwork(network);
    print('::::::2');

    if (blocs.isEmpty) return;
    print('::::::3');

    for (final bloc in blocs) {
      print('::::::4');

      final w = bloc.state.wallet!;
      bloc.add(LoadWallet(w.getWalletStorageString()));
    }
    print('::::::5');
  }

  // void addWallets(List<Wallet> wallets) {
  //   emit(state.copyWith(loadingWallets: true));

  //   final walletss = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
  //   walletss.addAll(wallets);

  //   emit(
  //     state.copyWith(
  //       wallets: walletss,
  //       loadingWallets: false,
  //     ),
  //   );
  // }

  // void removeWalletPostDelete(String id) {
  //   final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
  //   final walletBlocs = state.walletBlocs != null ? state.walletBlocs!.toList() : <WalletBloc>[];
  //   wallets.removeWhere(
  //     (w) => w.id == id,
  //   );
  //   walletBlocs.removeWhere((wB) => wB.state.wallet!.id == id);
  //   emit(
  //     state.copyWith(
  //       wallets: wallets,
  //       walletBlocs: walletBlocs,
  //       // selectedWallet: null,
  //     ),
  //   );
  // }

  // void updateSelectedWallet(WalletBloc walletBloc) {
  //   // final wallet = walletBloc.state.wallet!;
  //   // final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
  //   // final idx = wallets.indexWhere((w) => w.id == wallet.id);
  //   // wallets[idx] = wallet;

  //   emit(
  //     state.copyWith(
  //       // wallets: wallets,
  //       selectedWalletCubit: walletBloc,
  //     ),
  //   );
  // }

  // void walletSelected(WalletBloc walletBloc) async {
  //   await Future.delayed(500.microseconds);
  //   emit(state.copyWith(selectedWalletCubit: walletBloc));

  //   final network = walletBloc.state.wallet!.network;
  //   final idx = state.getWalletBlocIdx(walletBloc);

  //   emit(
  //     state.copyWith(
  //       lastMainnetWalletIdx: network == BBNetwork.Mainnet ? idx : state.lastMainnetWalletIdx,
  //       lastTestnetWalletIdx: network == BBNetwork.Testnet ? idx : state.lastTestnetWalletIdx,
  //     ),
  //   );
  // }

  // void changeMoveToIdx(Wallet wallet) async {
  //   final idx = state.getWalletIdx(wallet);
  //   emit(state.copyWith(moveToIdx: idx));
  //   await Future.delayed(const Duration(seconds: 5));
  //   emit(state.copyWith(moveToIdx: null));
  // }

  // void moveToLastWallet() async {
  //   await Future.delayed(const Duration(milliseconds: 500));

  //   emit(state.copyWith(moveToIdx: state.wallets!.length - 1));
  //   await Future.delayed(const Duration(seconds: 5));
  //   emit(state.copyWith(moveToIdx: null));
  // }

  // void networkChanged(BBNetwork network) async {
  //   final wallets = state.walletBlocsFromNetwork(network);
  //   if (wallets.isEmpty) {
  //     emit(state.copyWith(selectedWalletCubit: null));
  //     return;
  //   }

  //   final lastWalletIdx = state.getLastWalletIdx(network);
  //   if (lastWalletIdx != null && wallets.length > lastWalletIdx) {
  //     final wallet = wallets[lastWalletIdx].state.wallet!;
  //     changeMoveToIdx(wallet);
  //   } else
  //     emit(state.copyWith(selectedWalletCubit: wallets.first));
  // }

  void removeWallet(WalletBloc walletBloc) {
    // final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
    // wallets.removeWhere((w) => w.id == walletBloc.state.wallet!.id);
    final walletBlocs = state.walletBlocs != null
        ? state.walletBlocs!.toList()
        : <WalletBloc>[];
    walletBlocs.removeWhere(
      (wB) => wB.state.wallet!.id == walletBloc.state.wallet!.id,
    );

    emit(
      state.copyWith(
        // wallets: wallets,
        // selectedWalletCubit: null,
        walletBlocs: walletBlocs,
      ),
    );
  }
}
