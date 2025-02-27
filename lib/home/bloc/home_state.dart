import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_state.freezed.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    @Default([]) List<WalletServiceData> wallets,
    // List<Wallet>? tempwallets,
    // List<Wallet>? wallets,
    @Default(true) bool loadingWallets,
    @Default('') String errLoadingWallets,
    // Wallet? selectedWallet,
    // Wallet? selectedWalletCubit,
    // int? lastTestnetWalletIdx,
    // int? lastMainnetWalletIdx,
    @Default('') String errDeepLinking,
    @Default(false) bool updated,
    int? moveToIdx,
  }) = _HomeState;
  const HomeState._();

  bool syncingAny() => wallets.any((_) => _.syncing);

  bool hasWallets() => !loadingWallets && wallets.isNotEmpty;

  // List<Wallet> walletsFromNetwork(BBNetwork network) =>
  //     wallets?.where((wallet) => wallet.network == network).toList().reversed.toList() ?? [];

  bool hasMainWallets() => wallets.any((_) => _.wallet.mainWallet);

  List<Wallet> walletsFromNetwork(BBNetwork network) {
    final walletsData = wallets
        .where((_) => _.wallet.network == network)
        //.toList()
        //.reversed
        .toList();

    return walletsData.map((e) => e.wallet).toList();
  }

  List<Wallet> walletsFromNetworkExcludeWatchOnly(BBNetwork network) {
    final data = wallets
        .where(
          (d) => d.wallet.network == network && d.wallet.watchOnly() == false,
        )
        .toList();

    return data.map((e) => e.wallet).toList();
  }

  List<Wallet> walletsNotMainFromNetwork(BBNetwork network) {
    final blocs = wallets
        .where(
          (wallet) =>
              wallet.wallet.network == network && !wallet.wallet.mainWallet,
        )
        .toList()
        .reversed
        .toList();

    return blocs.map((e) => e.wallet).toList();
  }

  int lenWalletsFromNetwork(BBNetwork network) =>
      walletsFromNetwork(network).length;

  // List<Wallet> getMainWallets(bool isTestnet) {
  //   final network = isTestnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
  //   final instantwallet = getMainInstantWallet(network);
  //   final securewallet = getMainSecureWallet(network);
  //   return [
  //     if (instantwallet != null) instantwallet,
  //     if (securewallet != null) securewallet,
  //   ];
  // }

  // List<String> getMainWalletIDs(bool isTestnet) =>
  // getMainWallets(isTestnet).map((e) => e.id).toList();

  // Wallet? getMainInstantWallet(BBNetwork network) {
  //   final wallets = walletsFromNetwork(network);
  //   final idx = wallets.indexWhere(
  //     (w) => w.isInstant() && w.mainWallet,
  //   );
  //   if (idx == -1) return null;
  //   return wallets[idx];
  // }

  // Wallet? getMainSecureWallet(BBNetwork network) {
  //   final wallets = walletsFromNetwork(network);
  //   final idx = wallets.indexWhere(
  //     (w) => w.isSecure() && w.mainWallet,
  //   );
  //   if (idx == -1) return null;
  //   return wallets[idx];
  // }

  bool noNetworkWallets(BBNetwork network) =>
      walletsFromNetwork(network).isEmpty;

  Wallet? getWallet(Wallet wallet) {
    final wallets = walletsFromNetwork(wallet.network);
    final idx = wallets.indexWhere((w) => w.id == wallet.id);
    if (idx == -1) return null;
    return wallets[idx];
  }

  Wallet? getWalletFromTx(Transaction tx) {
    for (final walletBloc in wallets) {
      final wallet = walletBloc;
      if (wallet.wallet.transactions.indexWhere((t) => t.txid == tx.txid) !=
          -1) {
        return walletBloc.wallet;
      }
    }

    return null;
  }

  Wallet? getWalletFromSwapTx(SwapTx swaptx) {
    for (final walletBloc in wallets) {
      final wallet = walletBloc;
      if (wallet.wallet.transactions.indexWhere(
            (t) => t.swapTx?.id == swaptx.id,
          ) !=
          -1) {
        return walletBloc.wallet;
      }
    }

    return null;
  }

  // Wallet? getWalletFromTx(Transaction tx) {
  //   final walletBloc = getWalletFromTx(tx);
  //   return walletBloc?;
  // }

  bool walletIsLiquidFromTx(Transaction tx) {
    final wallet = getWalletFromTx(tx);
    if (wallet == null) return false;
    return wallet.isLiquid();
  }

  bool walletIsWatchOnlyFromTx(Transaction tx) {
    final walletBloc = getWalletById(tx.walletId!);
    return walletBloc?.watchOnly() ?? false;
  }

  Wallet? getWalletById(String id) {
    // final walletIdx = wallets!.indexWhere((w) => w.id == id);
    // if (walletIdx == -1) return null;
    // final wallet = wallets![walletIdx];
    // final wallets = walletsFromNetwork(wallet.network);
    final idx = wallets.indexWhere((w) => id == w.wallet.id);
    if (idx == -1) return null;
    return wallets[idx].wallet;
  }

  Wallet? getFirstWithSpendableAndBalance(BBNetwork network, {int amt = 0}) {
    final wallets = walletsFromNetwork(network);
    if (wallets.isEmpty) return null;
    Wallet? wallet;
    for (final w in wallets) {
      final ww = w;
      if (!ww.watchOnly()) {
        if ((ww.balance ?? 0) > amt) return ww;
        wallet = ww;
      }
    }
    return wallet;
  }

  SwapTx? getSwapTxById(String id) {
    for (final walletBloc in wallets) {
      final wallet = walletBloc;
      if (wallet.wallet.swaps.isEmpty) continue;
      final idx = wallet.wallet.swaps.indexWhere((_) => _.id == id);
      if (idx != -1) return wallet.wallet.swaps[idx];
    }

    for (final walletBloc in wallets) {
      final wallet = walletBloc;
      if (wallet.wallet.transactions.isEmpty) continue;
      final idx =
          wallet.wallet.transactions.indexWhere((_) => _.swapTx?.id == id);
      if (idx != -1) return wallet.wallet.transactions[idx].swapTx;
    }

    return null;
  }

  // Transaction? getTxFromSwap(SwapTx swap) {
  //   final isLiq = swap.isLiquid();
  //   final network = swap.network;
  //   final wallet = !isLiq
  //       ? getMainSecureWallet(network)?
  //       : getMainInstantWallet(network)?;
  //   if (wallet == null) return null;
  //   final idx = wallet.transactions.indexWhere((t) => t.swapTx?.id == swap.id);
  //   if (idx == -1) return null;
  //   return wallet.transactions[idx];
  // }

  // int? getLastWalletIdx(BBNetwork network) {
  //   if (network == BBNetwork.Testnet) return lastTestnetWalletIdx;
  //   return lastMainnetWalletIdx;
  // }

  int? getWalletIdx(Wallet wallet) {
    final walletssFromNetwork = walletsFromNetwork(wallet.network);
    final idx = walletssFromNetwork.indexWhere((w) => w.id == wallet.id);
    if (idx == -1) return null;
    return idx;
  }

  // int? getWalletIdx(Wallet walletBloc) {
  //   final walletssFromNetwork =
  //       walletsFromNetwork(walletBloc.network);
  //   final idx = walletssFromNetwork
  //       .indexWhere((w) => w.id == walletBloc.id);
  //   if (idx == -1) return null;
  //   return idx;
  // }

  // int? getSelectedWalletIdx() {
  //   if (selectedWalletCubit == null) return null;
  //   final walletsFromNetwork = walletsFromNetwork(selectedWalletCubit!!.network);
  //   final idx = walletsFromNetwork
  //       .indexWhere((w) => w!.id == selectedWalletCubit!!.id);
  //   if (idx == -1) return null;
  //   return idx;
  // }

  List<Transaction> allTxs(BBNetwork network) {
    final txs = <Transaction>[];
    for (final walletBloc in walletsFromNetwork(network)) {
      final walletTxs = walletBloc.transactions;
      // final wallet = walletBloc;
      for (final tx in walletTxs) {
        txs.add(tx);
      }
    }
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs;
  }

  List<Transaction> getAllTxs(BBNetwork network) {
    final txs = <Transaction>[];
    for (final walletBloc in walletsFromNetwork(network)) {
      final walletTxs = walletBloc.transactions;
      // final wallet = walletBloc;
      for (final tx in walletTxs) {
        // final isInSwapTx =
        //     swapTxs.where((swap) => swap.txid == tx.txid).isNotEmpty;
        // if (isInSwapTx == true) continue;
        txs.add(
          tx.copyWith(
            walletId: walletBloc.id,
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
    for (final walletBloc in walletsFromNetwork(network)) {
      final wallet = walletBloc;
      total += wallet.balance ?? 0;
    }
    return total;
  }

  Wallet? firstWalletWithEnoughBalance(int sats, BBNetwork network) {
    for (final wallet in walletsFromNetwork(network)) {
      final enoughBalance = wallet.balanceSats() >= sats;
      if (enoughBalance) return wallet;
    }
    return null;
  }

  Wallet? selectWalletWithHighestBalance(
    int sats,
    BBNetwork network, {
    bool onlyMain = false,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) {
    final List<Wallet> filteredWallets = walletsFromNetwork(network).where((w) {
      final wallet = w;
      if (onlyMain && !wallet.mainWallet) return false;
      if (onlyBitcoin && !wallet.isBitcoin()) return false;
      if (onlyLiquid && !wallet.isLiquid()) return false;
      return true;
    }).toList();
    Wallet? walletBlocWithHighestBalance;
    for (final wallet in filteredWallets) {
      final enoughBalance = wallet.balanceSats() >= sats;
      if (enoughBalance) {
        if (walletBlocWithHighestBalance == null ||
            wallet.balanceSats() > walletBlocWithHighestBalance.balanceSats()) {
          walletBlocWithHighestBalance = wallet;
        }
      }
    }

    if (walletBlocWithHighestBalance != null) {
      return walletBlocWithHighestBalance;
    }

    return null;
  }

  List<Wallet> walletsWithEnoughBalance(
    int sats,
    BBNetwork network, {
    bool onlyMain = false,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) {
    final wallets = walletsFromNetwork(network).where(
      (_) {
        final wallet = _;
        if (onlyMain && !wallet.mainWallet) return false;
        if (onlyBitcoin && !wallet.isBitcoin()) return false;
        if (onlyLiquid && !wallet.isLiquid()) return false;
        return true;
      },
    ).toList();

    final List<Wallet> walletsWithEnoughBalance = [];

    for (final walletBloc in wallets) {
      final enoughBalance = walletBloc.balanceSats() >= sats;
      if (enoughBalance) walletsWithEnoughBalance.add(walletBloc);
    }
    return walletsWithEnoughBalance.isEmpty
        ? wallets
        : walletsWithEnoughBalance;
  }

  Set<({String info, Wallet walletBloc})> homeWarnings(
    BBNetwork network,
  ) {
    bool instantBalWarning(Wallet wb) {
      if (wb.isInstant() == false) return false;
      return wb.balanceSats() > 100000000;
    }

    bool needsBackupWarning(Wallet wb) =>
        !wb.physicalBackupTested && !wb.vaultBackupTested;

    final warnings = <({String info, Wallet walletBloc})>{};
    final networkWallets = walletsFromNetwork(network);

    // Check for any wallet needing backup
    final walletNeedingBackup =
        networkWallets.where(needsBackupWarning).firstOrNull;
    if (walletNeedingBackup != null) {
      warnings.add(
        (
          info: 'Backup needs to be tested!',
          walletBloc: walletNeedingBackup,
        ),
      );
    }

    // Check for instant wallets with high balance
    for (final walletBloc in networkWallets) {
      if (instantBalWarning(walletBloc)) {
        warnings.add(
          (
            info: 'Instant wallet balance is high',
            walletBloc: walletBloc,
          ),
        );
      }
    }

    return warnings;
  }

  Wallet? findWalletWithSameFngr(Wallet wallet) {
    for (final wb in wallets) {
      final w = wb;
      if (w.wallet.id == wallet.id) continue;
      if (w.wallet.sourceFingerprint == wallet.sourceFingerprint) {
        return wb.wallet;
      }
    }
    return null;
  }

  // int? selectedWalletIdx(BBNetwork network) {
  //   final wallet = selectedWalletCubit?;
  //   if (wallet == null) return null;

  //   final wallets = walletsFromNetwork(network);
  //   for (var i = 0; i < wallets.length; i++)
  //     if (wallets[i].getWalletStorageString() == wallet.getWalletStorageString()) return i;

  //   return null;
  // }

  // static int? selectedWalletIdx({
  //   required Wallet selectedWalletCubit,
  //   required List<Wallet> walletCubits,
  // }) {
  //   final wallet = selectedWalletCubit;
  //   if (wallet == null) return -1;

  //   for (var i = 0; i < walletCubits.length; i++)
  //     if (walletCubits[i]!.getWalletStorageString() == wallet.getWalletStorageString())
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
