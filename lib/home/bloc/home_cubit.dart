import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required WalletsStorageRepository walletsStorageRepository,
    required AppWalletsRepository appWalletsRepository,
  })  : _walletsStorageRepository = walletsStorageRepository,
        _appWalletsRepository = appWalletsRepository,
        super(const HomeState());

  final WalletsStorageRepository _walletsStorageRepository;
  final AppWalletsRepository _appWalletsRepository;

  Future<void> getWalletsFromStorage() async {
    emit(state.copyWith(loadingWallets: true));

    await _appWalletsRepository.getWalletsFromStorage();

    // final (wallets, err) = await _walletsStorageRepository.readAllWallets();
    // if (err != null && err.toString() != 'No Key') {
    //   emit(state.copyWith(loadingWallets: false));
    //   return;
    // }

    // if (wallets == null) {
    //   emit(state.copyWith(loadingWallets: false));
    //   return;
    // }

    // await Future.delayed(const Duration(milliseconds: 300));

    emit(
      state.copyWith(
        // tempwallets: wallets,
        // walletBlocs: null,
        loadingWallets: false,
      ),
    );

    // if (err.toString() == 'No Key')
    //   createWalletCubit.createMne(
    //     fromHome: true,
    //   );
  }

  void clearWallets() => emit(state.copyWith(tempwallets: null));

  Future<void> updateErrDeepLink(String err) async {
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
        .indexWhere((wB) => wB.state.wallet.id == bloc.state.wallet.id);
    walletBlocs[idx] = bloc;

    emit(state.copyWith(walletBlocs: walletBlocs));

    updatedNotifier();
  }

  Future<void> updatedNotifier() async {
    emit(state.copyWith(updated: true));
    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(updated: false));
  }

  void loadWalletsForNetwork(BBNetwork network) {
    // final blocs = state.walletBlocsFromNetwork(network);
    final wallets = _appWalletsRepository.walletServiceFromNetwork(network);
    if (wallets.isEmpty) return;
    for (final w in wallets) {
      w.loadWallet();
    }

    // if (blocs.isEmpty) return;

    // for (final bloc in blocs) {
    // final w = bloc.state.wallet!;
    // bloc.add(LoadWallet(w.getWalletStorageString()));
    // }
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

  // void removeWallet(WalletBloc walletBloc) {
  //   // final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
  //   // wallets.removeWhere((w) => w.id == walletBloc.state.wallet!.id);
  //   final walletBlocs = state.walletBlocs != null
  //       ? state.walletBlocs!.toList()
  //       : <WalletBloc>[];
  //   walletBlocs.removeWhere(
  //     (wB) => wB.state.wallet!.id == walletBloc.state.wallet!.id,
  //   );

  //   emit(
  //     state.copyWith(
  //       // wallets: wallets,
  //       // selectedWalletCubit: null,
  //       walletBlocs: walletBlocs,
  //     ),
  //   );
  // }

  // void removeWallet2(Wallet wallet) {
  //   _appWalletsRepository.deleteWallet(wallet.id);
  //   // final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
  //   // wallets.removeWhere((w) => w.id == walletBloc.state.wallet!.id);
  //   // final walletBlocs = state.walletBlocs != null
  //   //     ? state.walletBlocs!.toList()
  //   //     : <WalletBloc>[];

  //   // walletBlocs.removeWhere(
  //   //   (wB) => wB.state.wallet!.id == walletBloc.state.wallet!.id,
  //   // );

  //   // emit(
  //   //   state.copyWith(
  //   //     // wallets: wallets,
  //   //     // selectedWalletCubit: null,
  //   //     walletBlocs: walletBlocs,
  //   //   ),
  //   // );
  // }
}
