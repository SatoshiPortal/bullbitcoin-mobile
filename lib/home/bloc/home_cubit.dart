import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/home/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this.createWalletCubit,
    required this.walletRead,
    required this.walletRepository,
    required this.hiveStorage,
  }) : super(const HomeState()) {
    createWalletCubitSubscription = createWalletCubit.stream.listen((state) {
      if (state.saved) getWalletsFromStorage();
    });
  }

  final WalletRead walletRead;
  final WalletRepository walletRepository;
  final HiveStorage hiveStorage;
  final CreateWalletCubit createWalletCubit;
  late final StreamSubscription createWalletCubitSubscription;

  @override
  Future<void> close() {
    createWalletCubitSubscription.cancel();
    return super.close();
  }

  Future<void> getWalletsFromStorage() async {
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

  void walletSelected(WalletBloc wallet) {
    emit(state.copyWith(selectedWalletCubit: wallet));
  }

  void updateSelectedWallet(WalletBloc walletBloc) {
    final wallet = walletBloc.state.wallet!;
    final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
    final idx = wallets.indexWhere((w) => w.mnemonicFingerprint == wallet.mnemonicFingerprint);
    wallets[idx] = wallet;

    emit(
      state.copyWith(
        wallets: wallets,
        selectedWalletCubit: walletBloc,
      ),
    );
  }

  void updateErrDeepLink(String err) async {
    emit(state.copyWith(errDeepLinking: err));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(errDeepLinking: ''));
  }

  void changeMoveToIdx(Wallet wallet) async {
    final idx = state.wallets!.indexWhere(
      (w) => w.getStorageString() == wallet.getStorageString(),
    );
    emit(state.copyWith(moveToIdx: idx));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(moveToIdx: null));
  }

  void moveToLastWallet() async {
    await Future.delayed(const Duration(milliseconds: 500));
    emit(state.copyWith(moveToIdx: state.wallets!.length - 1));
    await Future.delayed(const Duration(seconds: 5));
    emit(state.copyWith(moveToIdx: null));
  }

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

  void clearSelectedWallet({bool removeWallet = false}) {
    if (removeWallet) {
      final wallets = state.wallets != null ? state.wallets!.toList() : <Wallet>[];
      wallets.removeWhere(
        (w) =>
            w.mnemonicFingerprint == state.selectedWalletCubit!.state.wallet!.mnemonicFingerprint,
      );
      emit(
        state.copyWith(
          wallets: wallets,
          selectedWalletCubit: null,
          // selectedWallet: null,
        ),
      );
    } else
      emit(
        state.copyWith(
          selectedWalletCubit: null,
          // selectedWallet: null,
        ),
      );
  }
}
