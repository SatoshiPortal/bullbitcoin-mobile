import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/home/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this.createWalletCubit,
    required this.walletRepository,
    required this.hiveStorage,
  }) : super(const HomeState()) {
    createWalletCubitSubscription = createWalletCubit.stream.listen((state) {
      if (state.saved) getWalletsFromStorageExistingWallet();
    });
  }

  final WalletRepository walletRepository;
  final HiveStorage hiveStorage;
  final CreateWalletCubit createWalletCubit;
  late final StreamSubscription createWalletCubitSubscription;

  @override
  Future<void> close() {
    createWalletCubitSubscription.cancel();
    return super.close();
  }

  Future<void> getWalletsFromStorageFirstTime() async {
    emit(state.copyWith(loadingWallets: true));

    final (wallets, err) = await walletRepository.readAllWallets(hiveStore: hiveStorage);
    if (err != null && err.toString() != 'No Key') {
      emit(state.copyWith(loadingWallets: false));
      return;
    }

    if (wallets != null)
      emit(
        state.copyWith(
          wallets: wallets,
          loadingWallets: false,
        ),
      );

    if (err.toString() == 'No Key')
      createWalletCubit.createMne(
        fromHome: true,
      );
  }

  Future<void> getWalletsFromStorageExistingWallet() async {
    emit(state.copyWith(loadingWallets: true));

    final (wallets, err) = await walletRepository.readAllWallets(hiveStore: hiveStorage);
    if (err != null) {
      emit(state.copyWith(loadingWallets: false));
      return;
    }

    if (wallets != null)
      emit(
        state.copyWith(
          wallets: wallets,
          loadingWallets: false,
        ),
      );
  }

  void updateErrDeepLink(String err) async {
    emit(state.copyWith(errDeepLinking: err));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(errDeepLinking: ''));
  }

  void updateWalletBlocs(List<WalletBloc> blocs) => emit(state.copyWith(walletBlocs: blocs));

  void addWallet(Wallet wallet) {
    emit(state.copyWith(loadingWallets: true));

    final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
    wallets.add(wallet);

    emit(
      state.copyWith(
        wallets: wallets,
        loadingWallets: false,
      ),
    );
  }

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

  void updateSelectedWallet(WalletBloc walletBloc) {
    final wallet = walletBloc.state.wallet!;
    final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
    final idx = wallets.indexWhere((w) => w.id == wallet.id);
    wallets[idx] = wallet;

    emit(
      state.copyWith(
        wallets: wallets,
        selectedWalletCubit: walletBloc,
      ),
    );
  }

  void walletSelected(WalletBloc walletBloc) async {
    await Future.delayed(500.microseconds);
    emit(state.copyWith(selectedWalletCubit: walletBloc));

    final network = walletBloc.state.wallet!.network;
    final idx = state.getWalletBlocIdx(walletBloc);

    emit(
      state.copyWith(
        lastMainnetWalletIdx: network == BBNetwork.Mainnet ? idx : state.lastMainnetWalletIdx,
        lastTestnetWalletIdx: network == BBNetwork.Testnet ? idx : state.lastTestnetWalletIdx,
      ),
    );
  }

  void changeMoveToIdx(Wallet wallet) async {
    final idx = state.getWalletIdx(wallet);
    emit(state.copyWith(moveToIdx: idx));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(moveToIdx: null));
  }

  // void moveToLastWallet() async {
  //   await Future.delayed(const Duration(milliseconds: 500));

  //   emit(state.copyWith(moveToIdx: state.wallets!.length - 1));
  //   await Future.delayed(const Duration(seconds: 5));
  //   emit(state.copyWith(moveToIdx: null));
  // }

  void networkChanged(BBNetwork network) async {
    final wallets = state.walletBlocsFromNetwork(network);
    if (wallets.isEmpty) {
      emit(state.copyWith(selectedWalletCubit: null));
      return;
    }

    final lastWalletIdx = state.getLastWalletIdx(network);
    if (lastWalletIdx != null && wallets.length > lastWalletIdx) {
      final wallet = wallets[lastWalletIdx].state.wallet!;
      changeMoveToIdx(wallet);
    } else
      emit(state.copyWith(selectedWalletCubit: wallets.first));
  }

  void removeWallet(WalletBloc walletBloc) {
    final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
    wallets.removeWhere((w) => w.id == walletBloc.state.wallet!.id);
    emit(state.copyWith(wallets: wallets, selectedWalletCubit: null));
  }
}
