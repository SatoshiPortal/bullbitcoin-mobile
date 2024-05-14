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

  List<WalletBloc> walletBlocsFromNetwork(BBNetwork network) {
    final blocs = walletBlocs
            ?.where((wallet) => wallet.state.wallet?.network == network)
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

  bool walletIsLiquidFromTx(Transaction tx) {
    final wallet = getWalletFromTx(tx);
    return wallet?.baseWalletType == BaseWalletType.Liquid;
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

  Transaction? getTxFromSwap(SwapTx swap) {
    final isLiq = swap.walletType == BaseWalletType.Liquid;
    final network = swap.network;
    print('----> 1 $isLiq $network');
    final wallet = !isLiq
        ? getMainSecureWallet(network)?.state.wallet
        : getMainInstantWallet(network)?.state.wallet;
    print('----> 2 $wallet');
    if (wallet == null) return null;
    print('----> 3');
    final idx = wallet.transactions.indexWhere((t) => t.swapTx?.id == swap.id);
    print('----> 4 $idx');
    if (idx == -1) return null;
    print('----> 5');
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
      if (onlyBitcoin && wallet.baseWalletType != BaseWalletType.Bitcoin)
        return false;
      if (onlyLiquid && wallet.baseWalletType != BaseWalletType.Liquid)
        return false;
      return true;
    }).toList();
    WalletBloc? walletBlocWithHighestBalance;
    for (final walletBloc in filteredWallets) {
      final enoughBalance = walletBloc.state.balanceSats() >= sats;
      if (enoughBalance) {
        if (walletBlocWithHighestBalance == null ||
            walletBloc.state.balanceSats() >
                walletBlocWithHighestBalance.state.balanceSats())
          walletBlocWithHighestBalance = walletBloc;
      }
    }

    if (walletBlocWithHighestBalance != null)
      return walletBlocWithHighestBalance;

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
      (_) {
        final wallet = _.state.wallet!;
        if (onlyMain && !wallet.mainWallet) return false;
        if (onlyBitcoin && wallet.baseWalletType != BaseWalletType.Bitcoin)
          return false;
        if (onlyLiquid && wallet.baseWalletType != BaseWalletType.Liquid)
          return false;
        return true;
      },
    ).toList();

    final List<WalletBloc> walletsWithEnoughBalance = [];

    for (final walletBloc in wallets) {
      final enoughBalance = walletBloc.state.balanceSats() >= sats;
      if (enoughBalance) walletsWithEnoughBalance.add(walletBloc);
    }
    return walletsWithEnoughBalance;
  }

  Set<({String info, WalletBloc walletBloc})> homeWarnings(BBNetwork network) {
    bool instantBalWarning(WalletBloc wb) {
      if (wb.state.wallet?.type != BBWalletType.instant) return false;
      return wb.state.balanceSats() > 100000000;
    }

    bool backupWarning(WalletBloc wb) => !wb.state.wallet!.backupTested;

    final warnings = <({String info, WalletBloc walletBloc})>{};
    final List<String> backupWalletFngrforBackupWarning = [];

    for (final walletBloc in walletBlocsFromNetwork(network)) {
      if (instantBalWarning(walletBloc))
        warnings.add(
          (info: 'Instant wallet balance is high', walletBloc: walletBloc),
        );
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
