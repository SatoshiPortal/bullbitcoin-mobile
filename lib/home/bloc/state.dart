import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    List<Wallet>? wallets,
    @Default(true) bool loadingWallets,
    @Default('') String errLoadingWallets,
    // Wallet? selectedWallet,
    WalletCubit? selectedWalletCubit,
    @Default('') String errDeepLinking,
    int? moveToIdx,
  }) = _HomeState;
  const HomeState._();

  bool hasWallets() => !loadingWallets && wallets != null && wallets!.isNotEmpty;

  List<Wallet> walletsFromNetwork(BBNetwork network) =>
      wallets?.where((wallet) => wallet.network == network).toList().reversed.toList() ?? [];

  Wallet? getFirstWithSpendableAndBalance(BBNetwork network, {int amt = 0}) {
    final wallets = walletsFromNetwork(network);
    if (wallets.isEmpty) return null;
    Wallet? wallet;
    for (final w in wallets) {
      if (!w.watchOnly()) {
        if ((w.balance ?? 0) > amt) return w;
        wallet = w;
      }
    }
    return wallet;
  }

  static int? selectedWalletIdx({
    required WalletCubit selectedWalletCubit,
    required List<WalletCubit> walletCubits,
  }) {
    final wallet = selectedWalletCubit.state.wallet;
    if (wallet == null) return -1;

    for (var i = 0; i < walletCubits.length; i++)
      if (walletCubits[i].state.wallet!.getStorageString() == wallet.getStorageString()) return i;

    return null;
  }
}
