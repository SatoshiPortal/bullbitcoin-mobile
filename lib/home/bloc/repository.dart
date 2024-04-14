// // ignore_for_file: use_setters_to_change_properties

// import 'package:bb_mobile/_model/transaction.dart';
// import 'package:bb_mobile/_model/wallet.dart';
// import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';

// class HomeRepository {
//   // final List<Wallet> _wallets = [];
//   final List<WalletBloc> _walletBloc = [];
//   WalletBloc? _selectedWalletBloc;

//   // List<Wallet> get wallets => _wallets;
//   List<WalletBloc> get walletBlocs => _walletBloc;
//   WalletBloc? get selectedWalletBloc => _selectedWalletBloc;

//   void updateSelectedWalletBloc(WalletBloc? walletBloc) {
//     _selectedWalletBloc = walletBloc;
//   }

//   void getSelectedWalletBloc(WalletBloc? walletBloc) {
//     _selectedWalletBloc = walletBloc;
//   }

//   void updateWalletBlocs(List<WalletBloc> blocs) {
//     _walletBloc.clear();
//     _walletBloc.addAll(blocs);
//   }

//   // void updateWallets(List<Wallet> wallets) {
//   //   _wallets.clear();
//   //   _wallets.addAll(wallets);
//   // }

//   // void addWallets(List<Wallet> wallets) {
//   //   _wallets.addAll(wallets);
//   // }

//   // bool hasWallets() => wallets.isNotEmpty;

//   // List<Wallet> walletsFromNetwork(BBNetwork network) =>
//   //     wallets.where((wallet) => wallet.network == network).toList().reversed.toList();

//   List<WalletBloc> walletBlocsFromNetwork(BBNetwork network) {
//     final blocs = walletBlocs
//         .where((wallet) => wallet.state.wallet?.network == network)
//         .toList()
//         .reversed
//         .toList();

//     return blocs;
//   }

//   WalletBloc? getWalletBloc(Wallet wallet) {
//     final walletBlocs = walletBlocsFromNetwork(wallet.network);
//     final idx = walletBlocs.indexWhere((w) => w.state.wallet!.id == wallet.id);
//     if (idx == -1) return null;
//     return walletBlocs[idx];
//   }

//   WalletBloc? getWalletBlocById(String id) {
//     // final walletIdx = wallets!.indexWhere((w) => w.id == id);
//     // if (walletIdx == -1) return null;
//     // final wallet = wallets![walletIdx];
//     // final walletBlocs = walletBlocsFromNetwork(wallet.network);
//     final idx = walletBlocs.indexWhere((w) => id == w.state.wallet!.id);
//     if (idx == -1) return null;
//     return walletBlocs[idx];
//   }

//   // Wallet? getFirstWithSpendableAndBalance(BBNetwork network, {int amt = 0}) {
//   //   final wallets = walletsFromNetwork(network);
//   //   if (wallets.isEmpty) return null;
//   //   Wallet? wallet;
//   //   for (final w in wallets) {
//   //     if (!w.watchOnly()) {
//   //       if ((w.balance ?? 0) > amt) return w;
//   //       wallet = w;
//   //     }
//   //   }
//   //   return wallet;
//   // }

//   int? getWalletIdx(Wallet wallet) {
//     final walletsFromNetwork = walletBlocsFromNetwork(wallet.network);
//     final idx = walletsFromNetwork.indexWhere((w) => w.state.wallet!.id == wallet.id);
//     if (idx == -1) return null;
//     return idx;
//   }

//   int? getWalletBlocIdx(WalletBloc walletBloc) {
//     final walletsFromNetwork = walletBlocsFromNetwork(walletBloc.state.wallet!.network);
//     final idx =
//         walletsFromNetwork.indexWhere((w) => w.state.wallet!.id == walletBloc.state.wallet!.id);
//     if (idx == -1) return null;
//     return idx;
//   }

//   int? getSelectedWalletIdx() {
//     if (_selectedWalletBloc == null) return null;
//     final walletsFromNetwork = walletBlocsFromNetwork(_selectedWalletBloc!.state.wallet!.network);
//     final idx = walletsFromNetwork
//         .indexWhere((w) => w.state.wallet!.id == _selectedWalletBloc!.state.wallet!.id);
//     if (idx == -1) return null;
//     return idx;
//   }

//   List<Transaction> allTxs(BBNetwork network) {
//     final txs = <Transaction>[];
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final walletTxs = walletBloc.state.wallet?.transactions ?? <Transaction>[];
//       final wallet = walletBloc.state.wallet;
//       for (final tx in walletTxs) txs.add(tx.copyWith(wallet: wallet));
//     }
//     txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//     return txs;
//   }

//   List<Transaction> getAllTxs(BBNetwork network) {
//     final txs = <Transaction>[];
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final walletTxs = walletBloc.state.wallet?.transactions ?? <Transaction>[];
//       // final swapsTxs = walletBloc.state.wallet?.swaps ?? <SwapTx>[];
//       final wallet = walletBloc.state.wallet;
//       for (final tx in walletTxs) txs.add(tx.copyWith(wallet: wallet));
//       // for (final tx in swapsTxs) if (tx.swapTx != null) txs.add(tx.copyWith(wallet: wallet));
//     }

//     return _cleanandSortTxs(txs);
//   }

//   List<Transaction> _cleanandSortTxs(List<Transaction> txs) {
//     txs.sort((a, b) => b.timestamp.normaliseTime().compareTo(a.timestamp.normaliseTime()));
//     final zeroTxs = txs.where((tx) => tx.timestamp == 0).toList();
//     txs.removeWhere((tx) => tx.timestamp == 0);
//     txs.insertAll(0, zeroTxs);
//     return txs;
//   }

//   int totalBalanceSats(BBNetwork network) {
//     var total = 0;
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final wallet = walletBloc.state.wallet;
//       if (wallet == null) continue;
//       total += wallet.balance ?? 0;
//     }
//     return total;
//   }

//   WalletBloc? firstWalletWithEnoughBalance(int sats, BBNetwork network) {
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final enoughBalance = walletBloc.state.balanceSats() >= sats;
//       if (enoughBalance) return walletBloc;
//     }
//     return null;
//   }

//   Set<({String info, WalletBloc walletBloc})> homeWarnings(BBNetwork network) {
//     bool instantBalWarning(WalletBloc wb) {
//       if (wb.state.wallet?.type != BBWalletType.instant) return false;
//       return wb.state.balanceSats() > 100000000;
//     }

//     bool backupWarning(WalletBloc wb) => !wb.state.wallet!.backupTested;

//     final warnings = <({String info, WalletBloc walletBloc})>{};
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       if (instantBalWarning(walletBloc))
//         warnings.add((info: 'Instant wallet balance is high', walletBloc: walletBloc));
//       if (backupWarning(walletBloc))
//         warnings.add((info: 'Back up your wallet! Tap to test backup.', walletBloc: walletBloc));
//     }

//     return warnings;
//   }
// }

// extension Num on num {
//   int length() => toString().length;

//   int normaliseTime() {
//     final time = length() > 10 ? toInt() : toInt() * 1000;
//     // if (time < 10000000000) return time * 1000;
//     return time;
//   }
// }
