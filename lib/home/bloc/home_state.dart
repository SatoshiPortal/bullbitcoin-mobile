import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_state.freezed.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    List<Wallet>? tempwallets,
    List<WalletBloc>? walletBlocs,
    @Default(true) bool loadingWallets,
    @Default('') String errLoadingWallets,
    // Wallet? selectedWallet,
    // WalletBloc? selectedWalletCubit,
    // int? lastTestnetWalletIdx,
    // int? lastMainnetWalletIdx,
    @Default('') String errDeepLinking,
    @Default(false) bool updated,
    int? moveToIdx,
  }) = _HomeState;
  const HomeState._();

  bool hasWallets() =>
      !loadingWallets && walletBlocs != null && walletBlocs!.isNotEmpty;

  // List<WalletBloc> walletsFromNetwork(BBNetwork network) =>
  //     walletBlocs?.where((wallet) => wallet.network == network).toList().reversed.toList() ?? [];

  bool hasMainWallets() =>
      walletBlocs?.any((wallet) => wallet.state.wallet!.mainWallet) ?? false;

  List<WalletBloc> walletBlocsFromNetwork(BBNetwork network) {
    final blocs = walletBlocs
            ?.where((walletBloc) => walletBloc.state.wallet?.network == network)
            //.toList()
            //.reversed
            .toList() ??
        [];

    return blocs;
  }

  List<WalletBloc> walletBlocsFromNetworkExcludeWatchOnly(BBNetwork network) {
    final blocs = walletBlocs
            ?.where(
              (walletBloc) =>
                  walletBloc.state.wallet?.network == network &&
                  walletBloc.state.wallet!.watchOnly() == false,
            )
            .toList() ??
        [];

    return blocs;
  }

  List<WalletBloc> walletBlocsNotMainFromNetwork(BBNetwork network) {
    final blocs = walletBlocs
            ?.where(
              (wallet) =>
                  wallet.state.wallet?.network == network &&
                  !wallet.state.wallet!.mainWallet,
            )
            .toList()
            .reversed
            .toList() ??
        [];

    return blocs;
  }

  int lenWalletsFromNetwork(BBNetwork network) =>
      walletBlocsFromNetwork(network).length;

  List<WalletBloc> getMainWallets(bool isTestnet) {
    final network = isTestnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final instantwallet = getMainInstantWallet(network);
    final securewallet = getMainSecureWallet(network);
    return [
      if (instantwallet != null) instantwallet,
      if (securewallet != null) securewallet,
    ];
  }

  List<String> getMainWalletIDs(bool isTestnet) =>
      getMainWallets(isTestnet).map((e) => e.state.wallet!.id).toList();

  WalletBloc? getMainInstantWallet(BBNetwork network) {
    final wallets = walletBlocsFromNetwork(network);
    final idx = wallets.indexWhere(
      (w) => w.state.wallet!.isInstant() && w.state.wallet!.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }

  WalletBloc? getMainSecureWallet(BBNetwork network) {
    final wallets = walletBlocsFromNetwork(network);
    final idx = wallets.indexWhere(
      (w) => w.state.wallet!.isSecure() && w.state.wallet!.mainWallet,
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
      if (wallet.transactions.indexWhere((t) => t.txid == tx.txid) != -1) {
        return walletBloc;
      }
    }

    return null;
  }

  WalletBloc? getWalletBlocFromSwapTx(SwapTx swaptx) {
    if (walletBlocs == null) return null;

    for (final walletBloc in walletBlocs!) {
      final wallet = walletBloc.state.wallet;
      if (wallet == null) continue;
      if (wallet.transactions.indexWhere(
            (t) => t.swapTx?.id == swaptx.id,
          ) !=
          -1) return walletBloc;
    }

    return null;
  }

  Wallet? getWalletFromTx(Transaction tx) {
    final walletBloc = getWalletBlocFromTx(tx);
    return walletBloc?.state.wallet;
  }

  bool walletIsLiquidFromTx(Transaction tx) {
    final wallet = getWalletFromTx(tx);
    if (wallet == null) return false;
    return wallet.isLiquid();
  }

  bool walletIsWatchOnlyFromTx(Transaction tx) {
    final walletBloc = getWalletBlocById(tx.walletId!);
    return walletBloc?.state.wallet!.watchOnly() ?? false;
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

  SwapTx? getSwapTxById(String id) {
    for (final walletBloc in walletBlocs!) {
      final wallet = walletBloc.state.wallet;
      if (wallet == null || wallet.swaps.isEmpty) continue;
      final idx = wallet.swaps.indexWhere((e) => e.id == id);
      if (idx != -1) return wallet.swaps[idx];
    }

    for (final walletBloc in walletBlocs!) {
      final wallet = walletBloc.state.wallet;
      if (wallet == null || wallet.transactions.isEmpty) continue;
      final idx = wallet.transactions.indexWhere((e) => e.swapTx?.id == id);
      if (idx != -1) return wallet.transactions[idx].swapTx;
    }

    return null;
  }

  Transaction? getTxFromSwap(SwapTx swap) {
    final isLiq = swap.isLiquid();
    final network = swap.network;
    final wallet = !isLiq
        ? getMainSecureWallet(network)?.state.wallet
        : getMainInstantWallet(network)?.state.wallet;
    if (wallet == null) return null;
    final idx = wallet.transactions.indexWhere((t) => t.swapTx?.id == swap.id);
    if (idx == -1) return null;
    return wallet.transactions[idx];
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
      // final wallet = walletBloc.state.wallet;
      for (final tx in walletTxs) {
        txs.add(tx);
      }
    }
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs;
  }

  List<Transaction> getAllTxs(BBNetwork network) {
    final txs = <Transaction>[];
    for (final walletBloc in walletBlocsFromNetwork(network)) {
      final walletTxs =
          walletBloc.state.wallet?.transactions ?? <Transaction>[];
      // final wallet = walletBloc.state.wallet;
      for (final tx in walletTxs) {
        // final isInSwapTx =
        //     swapTxs.where((swap) => swap.txid == tx.txid).isNotEmpty;
        // if (isInSwapTx == true) continue;
        txs.add(
          tx.copyWith(
            walletId: walletBloc.state.wallet!.id,
          ),
        );
      }
      // for (final tx in swapsTxs) if (tx.swapTx != null) txs.add(tx.copyWith(wallet: wallet));
    }

    return _cleanandSortTxs(txs);
  }

  List<Transaction> _cleanandSortTxs(List<Transaction> txs) {
    txs.sort(
      (a, b) =>
          b.timestamp.normaliseTime().compareTo(a.timestamp.normaliseTime()),
    );

    // BEGIN: Chainswap filters: This is to show only Swap Txs and Swap refund Txs in home page,
    // by removing swap claimed txs
    final refundedSwapTxs = txs
        .where(
          (tx) =>
              tx.swapTx != null &&
              (tx.swapTx!.isChainSwap() || tx.swapTx!.refundedAny()),
        )
        .map((tx) => tx.swapTx)
        .toList();
    final toRemove = <Transaction>[];
    final txsToUpdate = <int, String>{};
    int index = 0;
    for (final tx in txs) {
      final isInSwapTxAndNotPending = refundedSwapTxs.where((swap) {
        if (swap!.refundedAny() && swap.claimTxid == tx.txid) {
          if (tx.label == null) {
            final String lbl = 'Refund: ${swap.id}';
            txsToUpdate.addAll({index: lbl});
          } else if (tx.label!.contains('Refund') == false) {
            final String lbl = '${tx.label}, Refund: ${swap.id}';
            txsToUpdate.addAll({index: lbl});
          }
          return false; // So it's not removed from here and shown in home page
        } else {
          return swap.claimTxid == tx.txid;
        }
      }) // && tx.timestamp != 0)
          .isNotEmpty;
      if (isInSwapTxAndNotPending) toRemove.add(tx);
      index++;
    }

    for (final index in txsToUpdate.keys) {
      txs[index] = txs[index].copyWith(label: txsToUpdate[index]);
    }

    for (final removeTx in toRemove) {
      txs.removeWhere((tx) => tx.txid == removeTx.txid);
    }
    // END: This is to show only Swap Txs in home page, by remove swap settle txs

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

  WalletBloc? selectWalletWithHighestBalance(
    int sats,
    BBNetwork network, {
    bool onlyMain = false,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) {
    final List<WalletBloc> filteredWallets =
        walletBlocsFromNetwork(network).where((w) {
      final wallet = w.state.wallet!;
      if (onlyMain && !wallet.mainWallet) return false;
      if (onlyBitcoin && !wallet.isBitcoin()) return false;
      if (onlyLiquid && !wallet.isLiquid()) return false;
      return true;
    }).toList();
    WalletBloc? walletBlocWithHighestBalance;
    for (final walletBloc in filteredWallets) {
      final enoughBalance = walletBloc.state.balanceSats() >= sats;
      if (enoughBalance) {
        if (walletBlocWithHighestBalance == null ||
            walletBloc.state.balanceSats() >
                walletBlocWithHighestBalance.state.balanceSats()) {
          walletBlocWithHighestBalance = walletBloc;
        }
      }
    }

    if (walletBlocWithHighestBalance != null) {
      return walletBlocWithHighestBalance;
    }

    return null;
  }

  List<WalletBloc> walletsWithEnoughBalance(
    int sats,
    BBNetwork network, {
    bool onlyMain = false,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) {
    final wallets = walletBlocsFromNetwork(network).where(
      (e) {
        final wallet = e.state.wallet!;
        if (onlyMain && !wallet.mainWallet) return false;
        if (onlyBitcoin && !wallet.isBitcoin()) return false;
        if (onlyLiquid && !wallet.isLiquid()) return false;
        return true;
      },
    ).toList();

    final List<WalletBloc> walletsWithEnoughBalance = [];

    for (final walletBloc in wallets) {
      final enoughBalance = walletBloc.state.balanceSats() >= sats;
      if (enoughBalance) walletsWithEnoughBalance.add(walletBloc);
    }
    return walletsWithEnoughBalance.isEmpty
        ? wallets
        : walletsWithEnoughBalance;
  }

  Set<({String info, WalletBloc walletBloc})> homeWarnings(BBNetwork network) {
    bool instantBalWarning(WalletBloc wb) {
      if (wb.state.wallet?.isInstant() == false) return false;
      return wb.state.balanceSats() > 100000000;
    }

    bool backupWarning(WalletBloc wb) => !wb.state.wallet!.backupTested;

    final warnings = <({String info, WalletBloc walletBloc})>{};
    final List<String> backupWalletFngrforBackupWarning = [];

    for (final walletBloc in walletBlocsFromNetwork(network)) {
      if (instantBalWarning(walletBloc)) {
        warnings.add(
          (info: 'Instant wallet balance is high', walletBloc: walletBloc),
        );
      }
      if (backupWarning(walletBloc)) {
        final fngr = walletBloc.state.wallet!.sourceFingerprint;
        if (backupWalletFngrforBackupWarning.contains(fngr)) continue;
        warnings.add(
          (
            info: 'Back up your wallet! Tap to test backup.',
            walletBloc: walletBloc
          ),
        );
        backupWalletFngrforBackupWarning.add(fngr);
      }
    }

    return warnings;
  }

  WalletBloc? findWalletBlocWithSameFngr(Wallet wallet) {
    for (final wb in walletBlocs!) {
      final w = wb.state.wallet!;
      if (w.id == wallet.id) continue;
      if (w.sourceFingerprint == wallet.sourceFingerprint) return wb;
    }
    return null;
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

extension Num on num {
  int length() => toString().length;

  int normaliseTime() {
    final time = length() > 10 ? toInt() : toInt() * 1000;
    // if (time < 10000000000) return time * 1000;
    return time;
  }
}
