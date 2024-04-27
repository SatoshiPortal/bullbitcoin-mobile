import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    // List<Wallet>? wallets,
    List<WalletBloc>? walletBlocs,
    @Default(true) bool loadingWallets,
    @Default('') String errLoadingWallets,
    // Wallet? selectedWallet,
    // WalletBloc? selectedWalletCubit,
    // int? lastTestnetWalletIdx,
    // int? lastMainnetWalletIdx,
    @Default('') String errDeepLinking,
    int? moveToIdx,
  }) = _HomeState;
  const HomeState._();

  bool hasWallets() =>
      !loadingWallets && walletBlocs != null && walletBlocs!.isNotEmpty;

  // List<WalletBloc> walletsFromNetwork(BBNetwork network) =>
  //     walletBlocs?.where((wallet) => wallet.network == network).toList().reversed.toList() ?? [];

  List<WalletBloc> walletBlocsFromNetwork(BBNetwork network) {
    final blocs = walletBlocs
            ?.where((wallet) => wallet.state.wallet?.network == network)
            .toList()
            .reversed
            .toList() ??
        [];

    return blocs;
  }

  List<WalletBloc> getMainWallets(bool isTestnet) {
    final network = isTestnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final instantwallet = getMainInstantWallet(network);
    final securewallet = getMainSecureWallet(network);
    return [
      if (instantwallet != null) instantwallet,
      if (securewallet != null) securewallet,
    ];
  }

  WalletBloc? getMainInstantWallet(BBNetwork network) {
    final wallets = walletBlocsFromNetwork(network);
    final idx = wallets.indexWhere(
      (w) =>
          w.state.wallet!.type == BBWalletType.instant &&
          w.state.wallet!.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }

  WalletBloc? getMainSecureWallet(BBNetwork network) {
    final wallets = walletBlocsFromNetwork(network);
    final idx = wallets.indexWhere(
      (w) =>
          w.state.wallet!.type != BBWalletType.instant &&
          w.state.wallet!.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }

  bool noNetworkWallets(BBNetwork network) =>
      walletBlocsFromNetwork(network).isEmpty;

  WalletBloc? getWalletBloc(Wallet wallet) {
    final walletBlocs = walletBlocsFromNetwork(wallet.network);
    final idx = walletBlocs.indexWhere((w) => w.state.wallet!.id == wallet.id);
    if (idx == -1) return null;
    return walletBlocs[idx];
  }

  WalletBloc? getWalletBlocFromTx(Transaction tx) {
    if (walletBlocs == null) return null;

    for (final walletBloc in walletBlocs!) {
      final wallet = walletBloc.state.wallet;
      if (wallet == null) continue;
      if (wallet.transactions.indexWhere((t) => t.txid == tx.txid) != -1)
        return walletBloc;
    }

    return null;
  }

  Wallet? getWalletFromTx(Transaction tx) {
    final walletBloc = getWalletBlocFromTx(tx);
    return walletBloc?.state.wallet;
  }

  WalletBloc? getWalletBlocById(String id) {
    // final walletIdx = wallets!.indexWhere((w) => w.id == id);
    // if (walletIdx == -1) return null;
    // final wallet = wallets![walletIdx];
    // final walletBlocs = walletBlocsFromNetwork(wallet.network);
    final idx = walletBlocs?.indexWhere((w) => id == w.state.wallet!.id);
    if (idx == -1 || idx == null) return null;
    return walletBlocs![idx];
  }

  Wallet? getFirstWithSpendableAndBalance(BBNetwork network, {int amt = 0}) {
    final wallets = walletBlocsFromNetwork(network);
    if (wallets.isEmpty) return null;
    Wallet? wallet;
    for (final w in wallets) {
      final ww = w.state.wallet;
      if (!ww!.watchOnly()) {
        if ((ww.balance ?? 0) > amt) return ww;
        wallet = ww;
      }
    }
    return wallet;
  }

  // int? getLastWalletIdx(BBNetwork network) {
  //   if (network == BBNetwork.Testnet) return lastTestnetWalletIdx;
  //   return lastMainnetWalletIdx;
  // }

  int? getWalletIdx(Wallet wallet) {
    final walletsFromNetwork = walletBlocsFromNetwork(wallet.network);
    final idx =
        walletsFromNetwork.indexWhere((w) => w.state.wallet!.id == wallet.id);
    if (idx == -1) return null;
    return idx;
  }

  int? getWalletBlocIdx(WalletBloc walletBloc) {
    final walletsFromNetwork =
        walletBlocsFromNetwork(walletBloc.state.wallet!.network);
    final idx = walletsFromNetwork
        .indexWhere((w) => w.state.wallet!.id == walletBloc.state.wallet!.id);
    if (idx == -1) return null;
    return idx;
  }

  // int? getSelectedWalletIdx() {
  //   if (selectedWalletCubit == null) return null;
  //   final walletsFromNetwork = walletBlocsFromNetwork(selectedWalletCubit!.state.wallet!.network);
  //   final idx = walletsFromNetwork
  //       .indexWhere((w) => w.state.wallet!.id == selectedWalletCubit!.state.wallet!.id);
  //   if (idx == -1) return null;
  //   return idx;
  // }

  List<Transaction> allTxs(BBNetwork network) {
    final txs = <Transaction>[];
    for (final walletBloc in walletBlocsFromNetwork(network)) {
      final walletTxs =
          walletBloc.state.wallet?.transactions ?? <Transaction>[];
      final wallet = walletBloc.state.wallet;
      for (final tx in walletTxs) txs.add(tx.copyWith(wallet: wallet));
    }
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs;
  }

  List<Transaction> getAllTxs(BBNetwork network) {
    final txs = <Transaction>[];
    for (final walletBloc in walletBlocsFromNetwork(network)) {
      final walletTxs =
          walletBloc.state.wallet?.transactions ?? <Transaction>[];
      // final swapsTxs = walletBloc.state.wallet?.swaps ?? <SwapTx>[];
      // final wallet = walletBloc.state.wallet;
      for (final tx in walletTxs) txs.add(tx);
      // for (final tx in swapsTxs) if (tx.swapTx != null) txs.add(tx.copyWith(wallet: wallet));
    }

    return _cleanandSortTxs(txs);
  }

  List<Transaction> _cleanandSortTxs(List<Transaction> txs) {
    txs.sort(
      (a, b) =>
          b.timestamp.normaliseTime().compareTo(a.timestamp.normaliseTime()),
    );
    final zeroTxs = txs.where((tx) => tx.timestamp == 0).toList();
    txs.removeWhere((tx) => tx.timestamp == 0);
    txs.insertAll(0, zeroTxs);
    return txs;
  }

  int totalBalanceSats(BBNetwork network) {
    var total = 0;
    for (final walletBloc in walletBlocsFromNetwork(network)) {
      final wallet = walletBloc.state.wallet;
      if (wallet == null) continue;
      total += wallet.balance ?? 0;
    }
    return total;
  }

  WalletBloc? firstWalletWithEnoughBalance(int sats, BBNetwork network) {
    for (final walletBloc in walletBlocsFromNetwork(network)) {
      final enoughBalance = walletBloc.state.balanceSats() >= sats;
      if (enoughBalance) return walletBloc;
    }
    return null;
  }

  Set<({String info, WalletBloc walletBloc})> homeWarnings(BBNetwork network) {
    bool instantBalWarning(WalletBloc wb) {
      if (wb.state.wallet?.type != BBWalletType.instant) return false;
      return wb.state.balanceSats() > 100000000;
    }

    bool backupWarning(WalletBloc wb) => !wb.state.wallet!.backupTested;

    final warnings = <({String info, WalletBloc walletBloc})>{};
    for (final walletBloc in walletBlocsFromNetwork(network)) {
      if (instantBalWarning(walletBloc))
        warnings.add(
          (info: 'Instant wallet balance is high', walletBloc: walletBloc),
        );
      if (backupWarning(walletBloc))
        warnings.add(
          (
            info: 'Back up your wallet! Tap to test backup.',
            walletBloc: walletBloc
          ),
        );
    }

    return warnings;
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

  List<WalletBloc> createWalletBlocs(List<Wallet> wallets) {
    final walletCubits = [
      for (final w in wallets)
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
}

extension Num on num {
  int length() => toString().length;

  int normaliseTime() {
    final time = length() > 10 ? toInt() : toInt() * 1000;
    // if (time < 10000000000) return time * 1000;
    return time;
  }
}
