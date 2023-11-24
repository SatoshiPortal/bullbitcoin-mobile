import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    List<Wallet>? wallets,
    List<WalletBloc>? walletBlocs,
    @Default(true) bool loadingWallets,
    @Default('') String errLoadingWallets,
    // Wallet? selectedWallet,
    WalletBloc? selectedWalletCubit,
    int? lastTestnetWalletIdx,
    int? lastMainnetWalletIdx,
    @Default('') String errDeepLinking,
    int? moveToIdx,
  }) = _HomeState;
  const HomeState._();

  bool hasWallets() => !loadingWallets && wallets != null && wallets!.isNotEmpty;

  List<Wallet> walletsFromNetwork(BBNetwork network) =>
      wallets?.where((wallet) => wallet.network == network).toList().reversed.toList() ?? [];

  List<WalletBloc> walletBlocsFromNetwork(BBNetwork network) {
    final blocs = walletBlocs
            ?.where((wallet) => wallet.state.wallet?.network == network)
            .toList()
            .reversed
            .toList() ??
        [];

    return blocs;
  }

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

  int? getLastWalletIdx(BBNetwork network) {
    if (network == BBNetwork.Testnet) return lastTestnetWalletIdx;
    return lastMainnetWalletIdx;
  }

  // int? selectedWalletIdx(BBNetwork network) {
  //   final wallet = selectedWalletCubit?.state.wallet;
  //   if (wallet == null) return null;

  //   final wallets = walletsFromNetwork(network);
  //   for (var i = 0; i < wallets.length; i++)
  //     if (wallets[i].getWalletStorageString() == wallet.getWalletStorageString()) return i;

  //   return null;
  // }

  // static int? selectedWalletIdx({
  //   required WalletBloc selectedWalletCubit,
  //   required List<WalletBloc> walletCubits,
  // }) {
  //   final wallet = selectedWalletCubit.state.wallet;
  //   if (wallet == null) return -1;

  //   for (var i = 0; i < walletCubits.length; i++)
  //     if (walletCubits[i].state.wallet!.getWalletStorageString() == wallet.getWalletStorageString())
  //       return i;

  //   return null;
  // }
}
