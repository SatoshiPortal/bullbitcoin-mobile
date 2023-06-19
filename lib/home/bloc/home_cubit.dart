import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/home/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required this.createWalletCubit,
    required this.walletRead,
    required this.storage,
  }) : super(const HomeState()) {
    // getWalletsFromStorage();
    createWalletCubitSubscription = createWalletCubit.stream.listen((state) {
      if (state.saved) getWalletsFromStorage();
    });
  }

  final WalletRead walletRead;
  final IStorage storage;

  final CreateWalletCubit createWalletCubit;
  late final StreamSubscription createWalletCubitSubscription;

  @override
  Future<void> close() {
    createWalletCubitSubscription.cancel();
    return super.close();
  }

  Future<void> getWalletsFromStorage() async {
    emit(state.copyWith(loadingWallets: true));

    final (wallets, err) =
        await walletRead.getWalletsFromStorage(storage: storage);
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

  void walletSelected(WalletCubit wallet) {
    emit(state.copyWith(selectedWalletCubit: wallet));
  }

  void updateSelectedWallet(WalletCubit walletCubit) {
    final wallet = walletCubit.state.wallet!;
    final wallets =
        state.wallets != null ? state.wallets!.toList() : <Wallet>[];
    final idx = wallets.indexWhere((w) => w.fingerprint == wallet.fingerprint);
    wallets[idx] = wallet;

    emit(
      state.copyWith(
        wallets: wallets,
        selectedWalletCubit: walletCubit,
      ),
    );
  }

  void addWallet(Wallet wallet) {
    emit(state.copyWith(loadingWallets: true));

    final wallets =
        state.wallets != null ? state.wallets!.toList() : <Wallet>[];
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
      final wallets =
          state.wallets != null ? state.wallets!.toList() : <Wallet>[];
      wallets.removeWhere(
        (w) =>
            w.fingerprint ==
            state.selectedWalletCubit!.state.wallet!.fingerprint,
      );
      emit(state.copyWith(
          wallets: wallets, selectedWalletCubit: null, selectedWallet: null));
    } else
      emit(state.copyWith(selectedWalletCubit: null, selectedWallet: null));
  }
}
