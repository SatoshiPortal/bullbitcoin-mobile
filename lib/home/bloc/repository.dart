// import 'package:bb_mobile/_model/transaction.dart';
// import 'package:bb_mobile/_model/wallet.dart';
// import 'package:bb_mobile/_pkg/error.dart';
// import 'package:bb_mobile/_pkg/logger.dart';
// import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
// import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
// import 'package:flutter/material.dart';

// class HomeRepository with ChangeNotifier {
//   HomeRepository({
//     required WalletsStorageRepository walletsStorageRepository,
//     required Logger logger,
//   })  : _walletsStorageRepository = walletsStorageRepository,
//         _logger = logger {
//     _init();
//   }

//   final WalletsStorageRepository _walletsStorageRepository;
//   final Logger _logger;

//   final List<Wallet> _walletBlocs = [];
//   List<Wallet> get walletBlocs => _walletBlocs;

//   void _init() async {
//     final err = await getWalletsFromStorage();
//     if (err != null) _logger.log(err.toString());
//   }

//   Future<Err?> getWalletsFromStorage() async {
//     try {
//       final (wallets, err) = await _walletsStorageRepository.readAllWallets();
//       if (err != null && err.toString() != 'No Key') return null;
//       if (err != null) throw err;

//       _walletBlocs.clear();
//       _walletBlocs.addAll(wallets ?? []);

//       notifyListeners();
//       return null;
//     } catch (e) {
//       return Err(e.toString());
//     }
//   }

//   List<Wallet> walletBlocsFromNetwork(BBNetwork network) {
//     final blocs =
//         _walletBlocs.where((wallet) => wallet.network == network).toList().reversed.toList();

//     return blocs;
//   }

//   Wallet? getMainInstantWallet(BBNetwork network) {
//     final wallets = walletBlocsFromNetwork(network);
//     final idx = wallets.indexWhere(
//       (w) => w.type == BBWalletType.instant && w.mainWallet,
//     );
//     if (idx == -1) return null;
//     return wallets[idx];
//   }

//   Wallet? getMainSecureWallet(BBNetwork network) {
//     final wallets = walletBlocsFromNetwork(network);
//     final idx = wallets.indexWhere(
//       (w) => w.type != BBWalletType.instant && w.mainWallet,
//     );
//     if (idx == -1) return null;
//     return wallets[idx];
//   }

//   bool noNetworkWallets(BBNetwork network) => walletBlocsFromNetwork(network).isEmpty;

//   Wallet? getWalletBloc(Wallet wallet) {
//     final walletBlocs = walletBlocsFromNetwork(wallet.network);
//     final idx = walletBlocs.indexWhere((w) => w.id == wallet.id);
//     if (idx == -1) return null;
//     return walletBlocs[idx];
//   }

//   Wallet? getWalletBlocById(String id) {
//     final idx = walletBlocs.indexWhere((w) => id == w.id);
//     if (idx == -1) return null;
//     return walletBlocs[idx];
//   }

//   int? getWalletIdx(Wallet wallet) {
//     final walletsFromNetwork = walletBlocsFromNetwork(wallet.network);
//     final idx = walletsFromNetwork.indexWhere((w) => w.id == wallet.id);
//     if (idx == -1) return null;
//     return idx;
//   }

//   int? getWalletBlocIdx(WalletBloc walletBloc) {
//     final walletsFromNetwork = walletBlocsFromNetwork(walletBloc.state.wallet!.network);
//     final idx = walletsFromNetwork.indexWhere((w) => w.id == walletBloc.state.wallet!.id);
//     if (idx == -1) return null;
//     return idx;
//   }

//   List<Transaction> allTxs(BBNetwork network) {
//     final txs = <Transaction>[];
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final walletTxs = walletBloc.transactions;
//       final wallet = walletBloc;
//       for (final tx in walletTxs) txs.add(tx.copyWith(wallet: wallet));
//     }
//     txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//     return txs;
//   }

//   List<Transaction> getAllTxs(BBNetwork network) {
//     final txs = <Transaction>[];
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final walletTxs = walletBloc.transactions;

//       final wallet = walletBloc;
//       for (final tx in walletTxs) txs.add(tx.copyWith(wallet: wallet));
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
//       final wallet = walletBloc;
//       total += wallet.balance ?? 0;
//     }
//     return total;
//   }

//   Set<({String info, Wallet walletBloc})> homeWarnings(BBNetwork network) {
//     bool instantBalWarning(Wallet wb) {
//       if (wb.type != BBWalletType.instant) return false;
//       return (wb.balance ?? 0) > 100000000;
//     }

//     bool backupWarning(Wallet wb) => !wb.backupTested;

//     final warnings = <({String info, Wallet walletBloc})>{};
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       if (instantBalWarning(walletBloc))
//         warnings.add((info: 'Instant wallet balance is high', walletBloc: walletBloc));
//       if (backupWarning(walletBloc))
//         warnings.add((info: 'Back up your wallet! Tap to test backup.', walletBloc: walletBloc));
//     }

//     return warnings;
//   }

//   Wallet? firstWalletWithEnoughBalance(int sats, BBNetwork network) {
//     for (final walletBloc in walletBlocsFromNetwork(network)) {
//       final enoughBalance = (walletBloc.balance ?? 0) >= sats;
//       if (enoughBalance) return walletBloc;
//     }
//     return null;
//   }
// }

// extension Num on num {
//   int length() => toString().length;

//   int normaliseTime() {
//     final time = length() > 10 ? toInt() : toInt() * 1000;

//     return time;
//   }
// }
