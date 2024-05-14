import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/address.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';

class WalletTx implements IWalletTransactions {
  WalletTx({
    required WalletsRepository walletsRepository,
    required WalletSensitiveStorageRepository walletSensitiveStorageRepository,
    required WalletAddress walletAddress,
    required WalletUpdate walletUpdate,
    required NetworkRepository networkRepository,
    required BDKTransactions bdkTransactions,
    required LWKTransactions lwkTransactions,
    required BDKAddress bdkAddress,
    required LWKAddress lwkAddress,
    required BDKUtxo bdkUtxo,
    required BDKSensitiveCreate bdkSensitiveCreate,
  })  : _walletsRepository = walletsRepository,
        _walletSensitiveStorageRepository = walletSensitiveStorageRepository,
        _walletAddress = walletAddress,
        _walletUpdate = walletUpdate,
        _bdkUtxo = bdkUtxo,
        _bdkTransactions = bdkTransactions,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        _networkRepository = networkRepository,
        _lwkTransactions = lwkTransactions,
        _bdkAddress = bdkAddress,
        _lwkAddress = lwkAddress;

  final WalletsRepository _walletsRepository;
  final NetworkRepository _networkRepository;
  final WalletSensitiveStorageRepository _walletSensitiveStorageRepository;

  final WalletAddress _walletAddress;
  final WalletUpdate _walletUpdate;
  final BDKSensitiveCreate _bdkSensitiveCreate;

  final BDKTransactions _bdkTransactions;
  final LWKTransactions _lwkTransactions;
  final BDKAddress _bdkAddress;
  final LWKAddress _lwkAddress;
  final BDKUtxo _bdkUtxo;

  @override
  Future<(Wallet?, Err?)> getTransactions(Wallet wallet) async {
    try {
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (bdkWallet, errWallet) =
              _walletsRepository.getBdkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final (walletWithDepositAddresses, errAddr1) =
              await _bdkAddress.loadAddresses(
            wallet: wallet,
            bdkWallet: bdkWallet!,
          );
          if (errAddr1 != null) throw errAddr1;
          final (walletWithChangeAddresses, errAddr2) =
              await _bdkAddress.loadChangeAddresses(
            wallet: walletWithDepositAddresses!,
            bdkWallet: bdkWallet,
          );
          if (errAddr2 != null) throw errAddr2;
          final (walletWithTxs, errTxs) =
              await _bdkTransactions.getTransactions(
            bdkWallet: bdkWallet,
            wallet: walletWithChangeAddresses!,
            walletAddress: _walletAddress,
          );
          if (errTxs != null) throw errTxs;
          final (walletWithTxAndAddresses, errUpdate) =
              await _walletUpdate.updateAddressesFromTxs(walletWithTxs!);
          if (errUpdate != null) throw errUpdate;
          final (walletwithUtxos, errUtxos) = await _bdkUtxo.loadUtxos(
            wallet: walletWithTxAndAddresses!,
            bdkWallet: bdkWallet,
          );
          if (errUtxos != null) throw errUtxos;
          final (walletUpdatedAddressesAndUtxos, errAddr3) =
              await _bdkAddress.updateUtxoAddresses(walletwithUtxos!);
          if (errAddr3 != null) throw errAddr3;
          return (walletUpdatedAddressesAndUtxos, null);

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) =
              _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final (walletWithDepositAddresses, errAddr) =
              await _lwkAddress.loadLiquidAddresses(
            wallet: wallet,
            lwkWallet: liqWallet!,
          );
          if (errAddr != null) throw errAddr;
          final (walletWithTxs, errTxs) =
              await _lwkTransactions.getLiquidTransactions(
            lwkWallet: liqWallet,
            wallet: walletWithDepositAddresses!,
          );
          if (errTxs != null) throw errTxs;
          return (walletWithTxs, null);
      }
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while getting transactions',
          solution: 'Please try again.',
        ),
      );
    }
  }

  @override
  Future<((Wallet?, Transaction?, int?)?, Err?)> buildTx({
    required Wallet wallet,
    required String address,
    required int? amount,
    required bool sendAllCoin,
    required double feeRate,
    String? note,
    required bool isManualSend,
    required bool enableRbf,
    List<UTXO>? selectedUtxos,
  }) async {
    try {
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (bdkWallet, errWallet) =
              _walletsRepository.getBdkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final (buildResp, err) = await _bdkTransactions.buildTx(
            wallet: wallet,
            pubWallet: bdkWallet!,
            isManualSend: isManualSend,
            address: address,
            amount: amount,
            sendAllCoin: sendAllCoin,
            feeRate: feeRate,
            enableRbf: enableRbf,
            selectedUtxos: selectedUtxos ?? [],
            note: note,
          );
          if (err != null) throw err;
          final (tx, feeAmt, psbt) = buildResp!;
          if (wallet.type == BBWalletType.secure ||
              wallet.type == BBWalletType.words) {
            final (seed, errSeed) =
                await _walletSensitiveStorageRepository.readSeed(
              fingerprintIndex: wallet.getRelatedSeedStorageString(),
            );
            if (errSeed != null) throw errSeed;
            final (bdkSignerWallet, errSigner) =
                await _bdkSensitiveCreate.loadPrivateBdkWallet(wallet, seed!);
            if (errSigner != null) throw errSigner;
            final (signed, errSign) = await _bdkTransactions.signTx(
              psbt: psbt,
              bdkWallet: bdkSignerWallet!,
            );
            if (errSign != null) throw errSign;
            return ((wallet, tx!.copyWith(psbt: signed!.$2), feeAmt), null);
          }

          final txs = wallet.transactions.toList();
          txs.add(tx!);
          final (w, errAdd) =
              await addUnsignedTxToWallet(transaction: tx, wallet: wallet);
          if (errAdd != null) throw errAdd;
          return ((w, tx, feeAmt), null);

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) =
              _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final (buildResp, errBuild) = await _lwkTransactions.buildLiquidTx(
            wallet: wallet,
            lwkWallet: liqWallet!,
            address: address,
            amount: amount,
            sendAllCoin: sendAllCoin,
            feeRate: feeRate,
          );
          if (errBuild != null) throw errBuild;
          final (tx, feeAmt, pset) = buildResp!;
          final (seed, errSeed) =
              await _walletSensitiveStorageRepository.readSeed(
            fingerprintIndex: wallet.getRelatedSeedStorageString(),
          );
          if (errSeed != null) throw errSeed;
          final (txBytes, errfinalize) = await _lwkTransactions.signTx(
            pset: pset,
            lwkWallet: liqWallet,
            wallet: wallet,
            seed: seed!,
          );
          if (errfinalize != null) throw errfinalize;
          return ((wallet, tx!.copyWith(pset: txBytes), feeAmt), null);
      }
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while building transaction',
          solution: 'Please try again.',
        ),
      );
    }
  }

  Future<(Wallet, Err?)> addUnsignedTxToWallet({
    required Transaction transaction,
    required Wallet wallet,
  }) async {
    try {
      final unsignedTxs = List<Transaction>.from(wallet.unsignedTxs);
      final index = unsignedTxs.indexWhere(
        (tx) => tx.txid == transaction.txid,
      );

      List<Transaction> updatedUnsignedTxs;

      if (index != -1) {
        updatedUnsignedTxs = wallet.unsignedTxs.map((tx) {
          return tx.txid == transaction.txid ? transaction : tx;
        }).toList();
      } else {
        updatedUnsignedTxs = List.from(wallet.unsignedTxs)..add(transaction);
      }

      final updatedWallet = wallet.copyWith(unsignedTxs: updatedUnsignedTxs);

      return (updatedWallet, null);
    } on Exception catch (e) {
      return (
        wallet,
        Err(
          e.message,
          title: 'Error occurred while adding unsigned transaction',
          solution: 'Please try again.',
        )
      ); // returning original wallet in case of error
    }
  }

  Future<(Wallet, Err?)> addSwapTxToWallet({
    required SwapTx swapTx,
    required Wallet wallet,
  }) async {
    try {
      final swaps = List<SwapTx>.from(wallet.swaps);
      final index = swaps.indexWhere(
        (swap) => swap.id == swapTx.id,
      );

      List<SwapTx> updatedSwaps;

      if (index != -1) {
        updatedSwaps = wallet.swaps.map((swap) {
          return swap.id == swapTx.id ? swapTx : swap;
        }).toList();
      } else {
        updatedSwaps = List.from(wallet.swaps)..add(swapTx);
      }

      final updatedWallet = wallet.copyWith(swaps: updatedSwaps);

      return (updatedWallet, null);
    } on Exception catch (e) {
      return (
        wallet,
        Err(
          e.message,
          title: 'Error occurred while adding swap transaction',
          solution: 'Please try again.',
        )
      ); // returning original wallet in case of error
    }
  }

  @override
  Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
    required Wallet wallet,
    required String address,
    required Transaction transaction,
    String? note,
  }) async {
    try {
      Wallet w;
      String txid;
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (blockchain, errNetwork) = _networkRepository.bdkBlockchain;
          if (errNetwork != null) throw errNetwork;
          final (walletAndTxid, errBroadcast) =
              await _bdkTransactions.broadcastTxWithWallet(
            psbt: transaction.psbt!,
            blockchain: blockchain!,
            wallet: wallet,
            address: address,
            transaction: transaction,
          );
          if (errBroadcast != null) throw errBroadcast;
          w = walletAndTxid!.$1;
          txid = walletAndTxid.$2;

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) =
              _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;

          final (walletAndTxid, errBroadcast) =
              await _lwkTransactions.broadcastLiquidTxWithWallet(
            lwkWallet: liqWallet!,
            transaction: transaction,
            wallet: wallet,
          );
          if (errBroadcast != null) throw errBroadcast;
          w = walletAndTxid!.$1;
          txid = walletAndTxid.$2;
      }

      final (_, updatedWallet) = await _walletAddress.addAddressToWallet(
        address: (null, address),
        wallet: w,
        label: note,
        spentTxId: txid,
        kind: AddressKind.external,
        state: AddressStatus.used,
      );

      return ((updatedWallet, txid), null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while broadcasting transaction',
          solution: 'Please try again.',
        ),
      );
    }
  }

  /// If given swap is expired,
  ///   - check if the swapTx has been refunded
  ///   - If yes, remove it from wallet.swaps
  ///   - if not, add it to the list of swaps to refund and return
  /// If not,
  ///   - update txid of wallet.swaps with swapTx.txid
  (({Wallet wallet})?, Err?) updateSwapTxs({
    required SwapTx swapTx,
    required Wallet wallet,
    bool deleteIfFailed = false,
  }) {
    final swaps = wallet.swaps;

    final idx = swaps.indexWhere((_) => _.id == swapTx.id);
    if (idx == -1) return (null, Err('No swapTx found'));

    final storedSwap = swaps[idx];

    final swapTxs = List<SwapTx>.from(swaps);

    final updatedSwapTx = storedSwap.copyWith(
      status: swapTx.status,
      txid: storedSwap.txid ?? swapTx.txid,
      keyIndex: storedSwap.keyIndex,
    );
    swapTxs[idx] = updatedSwapTx;
    final txs = wallet.transactions.toList();
    final isRevSub = !swapTx.isSubmarine;

    if (swapTx.txid != null) {
      final idx = txs.indexWhere((_) => _.txid == swapTx.txid);
      final idx2 = txs.indexWhere((_) => _.txid == swapTx.id);

      if (idx == -1 && idx2 == -1) {
        final newTx = Transaction(
          txid: swapTx.txid!,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          swapTx: updatedSwapTx,
          sent: isRevSub ? 0 : swapTx.outAmount - swapTx.totalFees()!,
          isSwap: true,
          received:
              isRevSub ? (swapTx.outAmount - (swapTx.totalFees() ?? 0)) : 0,
          fee: swapTx.claimFees,
          isLiquid: swapTx.isLiquid(),
        );
        txs.add(newTx);
      } else if (idx != -1) {
        final updatedTx = txs[idx].copyWith(
          swapTx: updatedSwapTx,
          isSwap: true,
        );
        txs[idx] = updatedTx;
      } else if (idx2 != -1) {
        final updatedTx = txs[idx2].copyWith(
          swapTx: updatedSwapTx,
          isSwap: true,
          txid: swapTx.txid!,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        txs[idx2] = updatedTx;
      }
    }

    if (swapTx.txid == null && swapTx.paidReverse()) {
      final idx = txs.indexWhere((_) => _.txid == swapTx.id);
      if (idx == -1) {
        final newTx = Transaction(
          txid: swapTx.id,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          swapTx: updatedSwapTx,
          sent: isRevSub ? 0 : swapTx.outAmount - swapTx.totalFees()!,
          isSwap: true,
          received:
              isRevSub ? (swapTx.outAmount - (swapTx.totalFees() ?? 0)) : 0,
          fee: swapTx.claimFees,
          isLiquid: swapTx.isLiquid(),
        );
        txs.add(newTx);
      } else {
        final updatedTx = txs[idx].copyWith(
          swapTx: updatedSwapTx,
          isSwap: true,
        );
        txs[idx] = updatedTx;
      }
    }

    final settled = swapTx.isSubmarine
        ? swapTx.settledSubmarine()
        : swapTx.settledReverse();

    if (settled) swapTxs.removeWhere((_) => _.id == swapTx.id);

    if (deleteIfFailed) {
      final swapsToDelete = <SwapTx>[
        for (final s in swapTxs)
          if (s.failed()) s,
      ];

      for (final s in swapsToDelete)
        if (swapsToDelete.any((_) => _.id == s.id))
          swapTxs.removeWhere((_) => _.id == s.id);
    }

    final updatedWallet = wallet.copyWith(swaps: swapTxs, transactions: txs);

    return ((wallet: updatedWallet), null);
  }

  // Future<(({Wallet wallet, SwapTx swapsToDelete})?, Err?)> mergeSwapTxIntoTx({
  //   required Wallet wallet,
  //   required SwapTx swapTx,
  // }) async {
  //   try {
  //     // final txs = wallet.transactions.toList();
  //     final swaps = wallet.swaps;
  //     final updatedSwaps = swaps.toList();
  //     // final swapsToDelete = <SwapTx>[];

  //     // final idx = txs.indexWhere((_) => _.txid == swapTx.txid);
  //     // if (idx == -1) return (null, Err('No new matching tx'));

  //     // final newTx = txs[idx].copyWith(
  //     // swapTx: swapTx,
  //     // );
  //     // txs[idx] = newTx;

  //     final swapToDelete = swaps.firstWhere((_) => _.id == swapTx.id);
  //     // swapsToDelete.add(swapToDelete);
  //     updatedSwaps.removeWhere((_) => _.id == swapTx.id);

  //     final updatedWallet = wallet.copyWith(
  //       // transactions: txs,
  //       swaps: updatedSwaps,
  //     );

  //     return ((wallet: updatedWallet, swapsToDelete: swapToDelete), null);
  //   } catch (e) {
  //     return (null, Err(e.toString()));
  //   }
  // }

  // Future<Err?> extractTx({
  //   required String tx,
  //   required HomeCubit homeCubit,
  // }) async {
  //   try {
  //     final (transaction, errExtract) = await _bdkTransactions.extractTx(tx: tx);
  //     if (errExtract != null) throw errExtract;
  //   } catch (e) {
  //     return Err(
  //       e.toString(),
  //       title: 'Error occurred while extracting transaction',
  //       solution: 'Please try again.',
  //     );
  //   }
  //   return null;
  // }
}

// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 

// class WalletTx {
//   Transaction addOutputAddresses(Address newAddress, Transaction tx) {
//     final outAddrs = List<Address>.from(tx.outAddrs);
//     final index = outAddrs.indexWhere(
//       (address) => address == newAddress,
//     );

//     if (index != -1) {
//       final updatedAddress = outAddrs.removeAt(index);
//       // (state: newAddress.state);
//       // outAddrs[index] = newAddress;
//       outAddrs.insert(index, updatedAddress.copyWith(state: newAddress.state));
//     } else {
//       outAddrs.add(newAddress);
//       // print(outAddrs);
//     }
//     return tx.copyWith(outAddrs: outAddrs);
//   }

//   Future<(Wallet, Err?)> addUnsignedTxToWallet({
//     required Transaction transaction,
//     required Wallet wallet,
//   }) async {
//     try {
//       final unsignedTxs = List<Transaction>.from(wallet.unsignedTxs);
//       final index = unsignedTxs.indexWhere(
//         (tx) => tx.txid == transaction.txid,
//       );

//       List<Transaction> updatedUnsignedTxs;

//       if (index != -1) {
//         updatedUnsignedTxs = wallet.unsignedTxs.map((tx) {
//           return tx.txid == transaction.txid ? transaction : tx;
//         }).toList();
//       } else {
//         updatedUnsignedTxs = List.from(wallet.unsignedTxs)..add(transaction);
//       }

//       final updatedWallet = wallet.copyWith(unsignedTxs: updatedUnsignedTxs);

//       return (updatedWallet, null);
//     } on Exception catch (e) {
//       return (
//         wallet,
//         Err(
//           e.message,
//           title: 'Error occurred while adding unsigned transaction',
//           solution: 'Please try again.',
//         )
//       ); // returning original wallet in case of error
//     }
//   }

//   Future<(Wallet, Err?)> addSwapTxToWallet({
//     required SwapTx swapTx,
//     required Wallet wallet,
//   }) async {
//     try {
//       final swaps = List<SwapTx>.from(wallet.swaps);
//       final index = swaps.indexWhere(
//         (swap) => swap.id == swapTx.id,
//       );

//       List<SwapTx> updatedSwaps;

//       if (index != -1) {
//         updatedSwaps = wallet.swaps.map((swap) {
//           return swap.id == swapTx.id ? swapTx : swap;
//         }).toList();
//       } else {
//         updatedSwaps = List.from(wallet.swaps)..add(swapTx);
//       }

//       final updatedWallet = wallet.copyWith(swaps: updatedSwaps);

//       return (updatedWallet, null);
//     } on Exception catch (e) {
//       return (
//         wallet,
//         Err(
//           e.message,
//           title: 'Error occurred while adding swap transaction',
//           solution: 'Please try again.',
//         )
//       ); // returning original wallet in case of error
//     }
//   }

//   /// If given swap is expired,
//   ///   - check if the swapTx has been refunded
//   ///   - If yes, remove it from wallet.swaps
//   ///   - if not, add it to the list of swaps to refund and return
//   /// If not,
//   ///   - update txid of wallet.swaps with swapTx.txid
//   (({Wallet wallet})?, Err?) updateSwapTxs({
//     required SwapTx swapTx,
//     required Wallet wallet,
//   }) {
//     final swaps = wallet.swaps;

//     final idx = swaps.indexWhere((_) => _.id == swapTx.id);
//     if (idx == -1) return (null, Err('No swapTx found'));

//     final storedSwap = swaps[idx];

//     final swapTxs = List<SwapTx>.from(swaps);

//     final updatedSwapTx = storedSwap.copyWith(
//       status: swapTx.status,
//       txid: storedSwap.txid ?? swapTx.txid,
//       keyIndex: storedSwap.keyIndex,
//     );
//     swapTxs[idx] = updatedSwapTx;

//     final swapsToDelete = <SwapTx>[
//       for (final s in swapTxs)
//         if (s.paidSubmarine || s.settledReverse || s.settledSubmarine || s.expiredReverse) s,
//     ];

//     for (final s in swapsToDelete)
//       if (swapsToDelete.any((_) => _.id == s.id)) swapTxs.removeWhere((_) => _.id == s.id);

//     final updatedWallet = wallet.copyWith(swaps: swapTxs);

//     return ((wallet: updatedWallet), null);
//   }

//   Future<(({Wallet wallet, SwapTx swapsToDelete})?, Err?)> mergeSwapTxIntoTx({
//     required Wallet wallet,
//     required SwapTx swapTx,
//   }) async {
//     try {
//       final txs = wallet.transactions.toList();
//       final swaps = wallet.swaps;
//       final updatedSwaps = swaps.toList();
//       // final swapsToDelete = <SwapTx>[];

//       final idx = txs.indexWhere((_) => _.txid == swapTx.txid);
//       if (idx == -1) return (null, Err('No new matching tx'));

//       final newTx = txs[idx].copyWith(
//         swapTx: swapTx,
//         isSwap: true,
//       );
//       txs[idx] = newTx;

//       final swapToDelete = swaps.firstWhere((_) => _.id == swapTx.id);
//       // swapsToDelete.add(swapToDelete);
//       updatedSwaps.removeWhere((_) => _.id == swapTx.id);

//       final updatedWallet = wallet.copyWith(
//         transactions: txs,
//         swaps: updatedSwaps,
//       );

//       return ((wallet: updatedWallet, swapsToDelete: swapToDelete), null);
//     } catch (e) {
//       return (null, Err(e.toString()));
//     }
//   }

//   //
//   // THIS NEEDS WORK
//   //
//   // Future<(Wallet?, Err?)> getTransactions({
//   //   required Wallet wallet,
//   //   required bdk.Wallet bdkWallet,
//   // }) async {
//   //   try {
//   //     final storedTxs = wallet.transactions.toList();
//   //     final unsignedTxs = wallet.unsignedTxs.toList();
//   //     final bdkNetwork = wallet.getBdkNetwork();
//   //     if (bdkNetwork == null) throw 'No bdkNetwork';

//   //     final txs = await bdkWallet.listTransactions(true);
//   //     // final x = bdk.TxBuilderResult();

//   //     if (txs.isEmpty) return (wallet, null);

//   //     final List<Transaction> transactions = [];

//   //     for (final tx in txs) {
//   //       String? label;

//   //       final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
//   //       final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

//   //       Transaction? storedTx;
//   //       if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
//   //       if (idxUnsignedTx != -1) {
//   //         if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
//   //       }
//   //       var txObj = Transaction(
//   //         txid: tx.txid,
//   //         received: tx.received,
//   //         sent: tx.sent,
//   //         fee: tx.fee ?? 0,
//   //         height: tx.confirmationTime?.height ?? 0,
//   //         timestamp: tx.confirmationTime?.timestamp ?? 0,
//   //         bdkTx: tx,
//   //         rbfEnabled: storedTx?.rbfEnabled ?? false,
//   //         outAddrs: storedTx?.outAddrs ?? [],
//   //         swapTx: storedTx?.swapTx,
//   //         isSwap: storedTx?.isSwap ?? false,
//   //       );
//   //       // var outAddrs;
//   //       // var inAddres;
//   //       final SerializedTx sTx = SerializedTx.fromJson(
//   //         jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
//   //       );
//   //       if (storedTxIdx != -1 &&
//   //           storedTxs[storedTxIdx].label != null &&
//   //           storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

//   //       Address? externalAddress;
//   //       Address? changeAddress;
//   //       Address? depositAddress;
//   //       const hexDecoder = HexDecoder();

//   //       if (!txObj.isReceived()) {
//   //         //
//   //         //
//   //         // HANDLE EXTERNAL RECIPIENT
//   //         //
//   //         //
//   //         externalAddress = wallet.getAddressFromAddresses(
//   //           txObj.txid,
//   //           isSend: !txObj.isReceived(),
//   //           kind: AddressKind.external,
//   //         );

//   //         final amountSentToExternal = tx.sent - (tx.received + (tx.fee ?? 0));

//   //         if (externalAddress != null) {
//   //           if (externalAddress.label != null && externalAddress.label!.isNotEmpty)
//   //             label = externalAddress.label;
//   //           else
//   //             externalAddress = externalAddress.copyWith(label: label);

//   //           // Future.delayed(const Duration(milliseconds: 100));
//   //         } else {
//   //           try {
//   //             if (sTx.output == null) throw 'No output object';
//   //             final scriptPubkeyString = sTx.output
//   //                 ?.firstWhere((output) => output.value == amountSentToExternal)
//   //                 .scriptPubkey;
//   //             // also check and update your own change, for older transactions
//   //             // this can help keep an index of change?
//   //             if (scriptPubkeyString == null) {
//   //               throw 'No script pubkey';
//   //             }
//   //             final scriptPubKey = await bdk.Script.create(
//   //               hexDecoder.convert(scriptPubkeyString) as Uint8List,
//   //             );

//   //             final addressStruct = await bdk.Address.fromScript(
//   //               scriptPubKey,
//   //               bdkNetwork,
//   //             );

//   //             (externalAddress, _) = await WalletAddresss().addAddressToWallet(
//   //               address: (null, addressStruct.toString()),
//   //               wallet: wallet.copyWith(),
//   //               spentTxId: tx.txid,
//   //               kind: AddressKind.external,
//   //               state: AddressStatus.used,
//   //               spendable: false,
//   //               label: label,
//   //             );
//   //             // Future.delayed(const Duration(milliseconds: 100));
//   //           } catch (e) {
//   //             // usually scriptpubkey not available
//   //             // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
//   //             // print(e);
//   //           }
//   //         }
//   //         txObj = txObj.copyWith(
//   //           toAddress: externalAddress != null ? externalAddress.address : '',
//   //           // fromAddress: '',
//   //         );
//   //         if (externalAddress != null) txObj = addOutputAddresses(externalAddress, txObj);
//   //         //
//   //         //
//   //         // HANDLE CHANGE
//   //         //
//   //         //

//   //         changeAddress = wallet.getAddressFromAddresses(
//   //           txObj.txid,
//   //           isSend: !txObj.isReceived(),
//   //           kind: AddressKind.change,
//   //         );

//   //         final amountChange = tx.received;

//   //         if (changeAddress != null) {
//   //           if (changeAddress.label != null && changeAddress.label!.isNotEmpty)
//   //             label = changeAddress.label;
//   //           else {
//   //             changeAddress = changeAddress.copyWith(label: label);
//   //           }
//   //         } else {
//   //           try {
//   //             if (sTx.output == null) throw 'No output object';
//   //             final scriptPubkeyString =
//   //                 sTx.output?.firstWhere((output) => output.value == amountChange).scriptPubkey;

//   //             if (scriptPubkeyString == null) {
//   //               throw 'No script pubkey';
//   //             }

//   //             final scriptPubKey = await bdk.Script.create(
//   //               hexDecoder.convert(scriptPubkeyString) as Uint8List,
//   //             );

//   //             final addressStruct = await bdk.Address.fromScript(
//   //               scriptPubKey,
//   //               bdkNetwork,
//   //             );

//   //             (changeAddress, _) = await WalletAddress().addAddressToWallet(
//   //               address: (null, addressStruct.toString()),
//   //               wallet: wallet,
//   //               spentTxId: tx.txid,
//   //               kind: AddressKind.change,
//   //               state: AddressStatus.used,
//   //               label: label,
//   //             );
//   //             // Future.delayed(const Duration(milliseconds: 100));
//   //           } catch (e) {
//   //             // usually scriptpubkey not available
//   //             // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
//   //             // print(e);
//   //           }
//   //         }
//   //         if (changeAddress != null) txObj = addOutputAddresses(changeAddress, txObj);
//   //       } else if (txObj.isReceived()) {
//   //         depositAddress = wallet.getAddressFromAddresses(
//   //           txObj.txid,
//   //           isSend: !txObj.isReceived(),
//   //           kind: AddressKind.deposit,
//   //         );
//   //         final amountReceived = tx.received;

//   //         if (depositAddress != null) {
//   //           if (depositAddress.label != null && depositAddress.label!.isNotEmpty)
//   //             label = depositAddress.label;
//   //           else
//   //             depositAddress = depositAddress.copyWith(label: label);
//   //         } else {
//   //           try {
//   //             if (sTx.output == null) throw 'No output object';
//   //             final scriptPubkeyString =
//   //                 sTx.output?.firstWhere((output) => output.value == amountReceived).scriptPubkey;

//   //             if (scriptPubkeyString == null) {
//   //               throw 'No script pubkey';
//   //             }

//   //             final scriptPubKey = await bdk.Script.create(
//   //               hexDecoder.convert(scriptPubkeyString) as Uint8List,
//   //             );
//   //             final addressStruct = await bdk.Address.fromScript(
//   //               scriptPubKey,
//   //               bdkNetwork,
//   //             );
//   //             (depositAddress, _) = await WalletAddress().addAddressToWallet(
//   //               address: (null, addressStruct.toString()),
//   //               wallet: wallet,
//   //               spentTxId: tx.txid,
//   //               kind: AddressKind.deposit,
//   //               state: AddressStatus.used,
//   //               spendable: false,
//   //               label: label,
//   //             );
//   //             // Future.delayed(const Duration(milliseconds: 100));
//   //           } catch (e) {
//   //             // usually scriptpubkey not available
//   //             // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
//   //             // print(e);
//   //           }
//   //         }
//   //         txObj = txObj.copyWith(
//   //           toAddress: depositAddress != null ? depositAddress.address : '',
//   //           // fromAddress: '',
//   //         );
//   //         if (depositAddress != null) {
//   //           final txObj2 = addOutputAddresses(depositAddress, txObj);
//   //           txObj = txObj2.copyWith(outAddrs: txObj2.outAddrs);
//   //         }
//   //       }

//   //       if (storedTxIdx != -1 &&
//   //           storedTxs[storedTxIdx].label != null &&
//   //           storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

//   //       transactions.add(txObj.copyWith(label: label));
//   //       // Future.delayed(const Duration(milliseconds: 100));
//   //     }

//   //     // Future.delayed(const Duration(milliseconds: 200));
//   //     final w = wallet.copyWith(
//   //       transactions: transactions,
//   //       unsignedTxs: unsignedTxs,
//   //     );

//   //     return (w, null);
//   //   } on Exception catch (e) {
//   //     return (
//   //       null,
//   //       Err(
//   //         e.message,
//   //         title: 'Error occurred while getting transactions',
//   //         solution: 'Please try again.',
//   //       )
//   //     );
//   //   }
//   // }

//   // Future<(Wallet?, Err?)> getTransactionsNew({
//   //   required Wallet wallet,
//   //   required bdk.Wallet bdkWallet,
//   // }) async {
//   //   try {
//   //     final storedTxs = wallet.transactions;
//   //     final unsignedTxs = wallet.unsignedTxs;
//   //     final bdkNetwork = wallet.getBdkNetwork();
//   //     if (bdkNetwork == null) throw 'No bdkNetwork';

//   //     final txs = await bdkWallet.listTransactions(true);
//   //     // final x = bdk.TxBuilderResult();

//   //     if (txs.isEmpty) return (wallet, null);

//   //     final List<Transaction> transactions = [];

//   //     for (final tx in txs) {
//   //       String? label;

//   //       final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
//   //       final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

//   //       Transaction? storedTx;
//   //       if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
//   //       if (idxUnsignedTx != -1) {
//   //         if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
//   //       }
//   //       var txObj = Transaction(
//   //         txid: tx.txid,
//   //         received: tx.received,
//   //         sent: tx.sent,
//   //         fee: tx.fee ?? 0,
//   //         height: tx.confirmationTime?.height ?? 0,
//   //         timestamp: tx.confirmationTime?.timestamp ?? 0,
//   //         bdkTx: tx,
//   //         rbfEnabled: storedTx?.rbfEnabled ?? false,
//   //         outAddrs: storedTx?.outAddrs ?? [],
//   //       );

//   //       if (storedTxIdx != -1 &&
//   //           storedTxs[storedTxIdx].label != null &&
//   //           storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

//   //       final SerializedTx sTx = SerializedTx.fromJson(
//   //         jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
//   //       );

//   //       const hexDecoder = HexDecoder();
//   //       final outputs = sTx.output;

//   //       for (final output in outputs!) {
//   //         final scriptPubKey = await bdk.Script.create(
//   //           hexDecoder.convert(output.scriptPubkey!) as Uint8List,
//   //         );

//   //         final addressStruct = await bdk.Address.fromScript(
//   //           scriptPubKey,
//   //           bdkNetwork,
//   //         );

//   //         final existing = wallet.findAddressInWallet(addressStruct.toString());
//   //         if (existing != null) {
//   //           // txObj.outAddrs.add(existing);
//   //           if (existing.label == null && existing.label!.isEmpty)
//   //             txObj = addOutputAddresses(existing.copyWith(label: label), txObj);
//   //           else {
//   //             label ??= existing.label;
//   //             txObj = addOutputAddresses(existing, txObj);
//   //           }
//   //         } else {
//   //           if (txObj.isReceived()) {
//   //             // AddressKind.deposit should exist in the addressBook
//   //             // may not be applicable for payjoin
//   //           } else {
//   //             // AddressKind.external wont exist for imported wallets and must be added here
//   //             // AddressKind.change should exist in the addressBook
//   //             final (externalAddress, _) = await WalletAddress().addAddressToWallet(
//   //               address: (null, addressStruct.toString()),
//   //               wallet: wallet,
//   //               spentTxId: tx.txid,
//   //               kind: AddressKind.external,
//   //               state: AddressStatus.used,
//   //               spendable: false,
//   //               label: label,
//   //             );
//   //             txObj = addOutputAddresses(externalAddress, txObj);
//   //           }
//   //         }
//   //       }

//   //       if (txObj.isReceived()) {
//   //         final recipients = txObj.outAddrs
//   //             .where((element) => element.kind == AddressKind.deposit)
//   //             .toList()
//   //             .map((e) => e.address);
//   //         // may break for payjoin

//   //         txObj = txObj.copyWith(
//   //           toAddress: recipients.toString(),
//   //         );
//   //       } else {
//   //         final recipients = txObj.outAddrs
//   //             .where((element) => element.kind == AddressKind.external)
//   //             .toList()
//   //             .map((e) => e.address);
//   //         txObj = txObj.copyWith(
//   //           toAddress: recipients.toString(),
//   //         );
//   //       }

//   //       transactions.add(txObj.copyWith(label: label));
//   //     }

//   //     final w = wallet.copyWith(
//   //       transactions: transactions,
//   //       unsignedTxs: unsignedTxs,
//   //     );

//   //     return (w, null);
//   //   } on Exception catch (e) {
//   //     return (
//   //       null,
//   //       Err(
//   //         e.message,
//   //         title: 'Error occurred while getting transactions',
//   //         solution: 'Please try again.',
//   //       )
//   //     );
//   //   }
//   // }

//   Future<(Wallet?, Err?)> getLiquidTransactions({
//     required Wallet wallet,
//     required lwk.Wallet lwkWallet,
//   }) async {
//     try {
//       final storedTxs = wallet.transactions.toList();
//       final unsignedTxs = wallet.unsignedTxs.toList();

//       final txs = await lwkWallet.txs();

//       if (txs.isEmpty) return (wallet, null);

//       final List<Transaction> transactions = [];

//       for (final tx in txs) {
//         String? label;

//         final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
//         final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

//         Transaction? storedTx;
//         if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
//         if (idxUnsignedTx != -1) {
//           if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
//         }
//         final assetToPick =
//             wallet.network == BBNetwork.LMainnet ? lwk.lBtcAssetId : lwk.lTestAssetId;
//         final balances = tx.balances;
//         final finalBalance = balances.where((e) => e.$1 == assetToPick).map((e) => e.$2).first;
//         final txObj = Transaction(
//           txid: tx.txid,
//           received: tx.kind == 'outgoing' ? 0 : finalBalance,
//           sent: tx.kind == 'outgoing' ? finalBalance : 0,
//           fee: tx.fee ?? 0,
//           height: 100,
//           timestamp: tx.timestamp,
//           rbfEnabled: false,
//           outAddrs: storedTx?.outAddrs ??
//               tx.outputs
//                   .map(
//                     (e) => Address(
//                       address: e.scriptPubkey,
//                       kind: AddressKind.deposit,
//                       state: AddressStatus.active,
//                     ),
//                   )
//                   .toList(),
//         );

//         transactions.add(txObj);
//       }

//       // Future.delayed(const Duration(milliseconds: 200));
//       final w = wallet.copyWith(
//         transactions: transactions,
//         unsignedTxs: unsignedTxs,
//       );

//       return (w, null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while getting transactions',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<((Transaction?, int?, String)?, Err?)> buildLiquidTx({
//     required Wallet wallet,
//     required lwk.Wallet lwkWallet,
//     required String address,
//     required int? amount,
//     required bool sendAllCoin,
//     required double feeRate,
//   }) async {
//     try {
//       final isMainnet = wallet.network == BBNetwork.LMainnet;
//       // if (isMainnet != isLiquidMainnetAddress(address)) {
//       //   return (
//       //     null,
//       //     Err('Invalid Address. Network Mismatch!'),
//       //   );
//       // }
//       final pset = await lwkWallet.build(sats: amount ?? 0, outAddress: address, absFee: feeRate);
//       // pubWallet.sign(network: wallet.network == BBNetwork.LMainnet ? lwk.Network.Mainnet : lwk.Network.Testnet , pset: pset, mnemonic: mnemonic)

//       final Transaction tx = Transaction(
//         txid: '',
//         received: 0,
//         sent: amount ?? 0,
//         fee: feeRate.toInt() ?? 0,
//         height: 0,
//         timestamp: 0,
//         label: '',
//         toAddress: address,
//         outAddrs: [],
//         psbt: pset,
//       );
//       return ((tx, feeRate.toInt(), pset), null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while building transaction',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<((Transaction?, int?, String)?, Err?)> buildTx({
//     required Wallet wallet,
//     required bdk.Wallet pubWallet,
//     required bool isManualSend,
//     required String address,
//     required int? amount,
//     required bool sendAllCoin,
//     required double feeRate,
//     required bool enableRbf,
//     required List<UTXO> selectedUtxos,
//     String? note,
//   }) async {
//     try {
//       final isMainnet = wallet.network == BBNetwork.Mainnet;
//       if (isMainnet != isMainnetAddress(address)) {
//         return (
//           null,
//           Err('Invalid Address. Network Mismatch!'),
//         );
//       }
//       var txBuilder = bdk.TxBuilder();
//       final bdkAddress = await bdk.Address.create(address: address);
//       final script = await bdkAddress.scriptPubKey();
//       if (sendAllCoin) {
//         txBuilder = txBuilder.drainWallet().drainTo(script);
//       } else {
//         txBuilder = txBuilder.addRecipient(script, amount!);
//       }

//       for (final address in wallet.allFreezedAddresses())
//         for (final unspendable in address.getUnspentUtxosOutpoints(wallet.utxos))
//           txBuilder = txBuilder.addUnSpendable(unspendable);

//       if (isManualSend) {
//         txBuilder = txBuilder.manuallySelectedOnly();
//         final List<bdk.OutPoint> utxos = selectedUtxos.map((e) {
//           return bdk.OutPoint(txid: e.txid, vout: e.txIndex);
//         }).toList();
//         /*
//         for (final address in selectedUtxos)
//           utxos.addAll(address.getUnspentUtxosOutpoints(wallet.utxos));
//           */
//         txBuilder = txBuilder.addUtxos(utxos);
//       }

//       txBuilder = txBuilder.feeRate(feeRate);

//       if (enableRbf) txBuilder = txBuilder.enableRbf();

//       final txResult = await txBuilder.finish(pubWallet);

//       final txDetails = txResult.txDetails;

//       final extractedTx = await txResult.psbt.extractTx();
//       final outputs = await extractedTx.output();

//       final bdkNetwork = wallet.getBdkNetwork();
//       if (bdkNetwork == null) throw 'No bdkNetwork';

//       final outAddrsFutures = outputs.map((txOut) async {
//         final scriptAddress = await bdk.Address.fromScript(
//           txOut.scriptPubkey,
//           bdkNetwork,
//         );
//         if (txOut.value == amount! && !sendAllCoin && scriptAddress.toString() == address) {
//           return Address(
//             address: scriptAddress.toString(),
//             kind: AddressKind.external,
//             state: AddressStatus.used,
//             highestPreviousBalance: amount,
//             balance: amount,
//             label: note ?? '',
//             spendable: false,
//           );
//         } else {
//           return Address(
//             address: scriptAddress.toString(),
//             kind: AddressKind.change,
//             state: AddressStatus.used,
//             highestPreviousBalance: txOut.value,
//             balance: txOut.value,
//             label: note ?? '',
//           );
//         }
//       });

//       final List<Address> outAddrs = await Future.wait(outAddrsFutures);
//       final feeAmt = await txResult.psbt.feeAmount();

//       final Transaction tx = Transaction(
//         txid: txDetails.txid,
//         rbfEnabled: enableRbf,
//         received: txDetails.received,
//         sent: txDetails.sent,
//         fee: feeAmt ?? 0,
//         height: txDetails.confirmationTime?.height,
//         timestamp: txDetails.confirmationTime?.timestamp ?? 0,
//         label: note,
//         toAddress: address,
//         outAddrs: outAddrs,
//         psbt: txResult.psbt.psbtBase64,
//       );
//       return ((tx, feeAmt, txResult.psbt.psbtBase64), null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while building transaction',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<(Uint8List?, Err?)> finalizeLiquidTx({
//     required String pset,
//     required lwk.Wallet lwkWallet,
//     required Wallet wallet,
//     // required SecureStorage secureStorage,
//     required Seed seed,
//   }) async {
//     try {
//       // final (seed, sErr) = await locator<WalletSensitiveStorageRepository>().readSeed(
//       //   fingerprintIndex: wallet.getRelatedSeedStorageString(),
//       // );

//       // if (sErr != null) {
//       //   return (
//       //     null,
//       //     Err(
//       //       sErr.toString(),
//       //       title: 'Error occurred while finalizing transaction',
//       //       solution: 'Please try again.',
//       //     ),
//       //   );
//       // }

//       final signedTx = await lwkWallet.sign(
//         network: wallet.network == BBNetwork.LMainnet ? lwk.Network.Mainnet : lwk.Network.Testnet,
//         pset: pset,
//         mnemonic: seed.mnemonic,
//       );
//       return (signedTx, null);
//     } catch (e) {
//       return (
//         null,
//         Err(
//           e.toString(),
//           title: 'Error occurred while signing transaction',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<(bdk.Transaction?, Err?)> finalizeTx({
//     required String psbt,
//     // required bdk.Blockchain blockchain,
//     required bdk.Wallet bdkWallet,
//     // required String address,
//   }) async {
//     try {
//       final psbtStruct = bdk.PartiallySignedTransaction(psbtBase64: psbt);
//       // final tx = await psbtStruct.extractTx();
//       final finalized = await bdkWallet.sign(
//         psbt: psbtStruct,
//         signOptions: const bdk.SignOptions(
//           isMultiSig: false,
//           trustWitnessUtxo: false,
//           allowAllSighashes: false,
//           removePartialSigs: true,
//           tryFinalize: true,
//           signWithTapInternalKey: false,
//           allowGrinding: true,
//         ),
//       );
//       final extracted = await finalized.extractTx();

//       return (extracted, null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while signing transaction',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<((Wallet, String)?, Err?)> broadcastLiquidTxWithWallet({
//     required Uint8List txBytes,
//     required Wallet wallet,
//     required lwk.Wallet lwkWallet,
//     required Transaction transaction,
//   }) async {
//     try {
//       final txid = await lwkWallet.broadcast(electrumUrl: 'blockstream.info:465', txBytes: txBytes);
//       final newTx = transaction.copyWith(
//         txid: txid,
//         broadcastTime: DateTime.now().millisecondsSinceEpoch,
//       );

//       final txs = wallet.transactions.toList();
//       // final txs = walletBloc.state.wallet!.transactions.toList();
//       final idx = txs.indexWhere((element) => element.txid == newTx.txid);
//       if (idx != -1) {
//         txs.removeAt(idx);
//         txs.insert(idx, newTx);
//       } else
//         txs.add(newTx);
//       final w = wallet.copyWith(transactions: txs);

//       return ((w, txid), null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while broadcasting transaction',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
//     required String psbt,
//     required bdk.Blockchain blockchain,
//     required Wallet wallet,
//     required String address,
//     required Transaction transaction,
//     String? note,
//   }) async {
//     try {
//       final psbtStruct = bdk.PartiallySignedTransaction(psbtBase64: psbt);
//       final tx = await psbtStruct.extractTx();

//       await blockchain.broadcast(tx);
//       final txid = await psbtStruct.txId();
//       final newTx = transaction.copyWith(
//         txid: txid,
//         label: note,
//         toAddress: address,
//         broadcastTime: DateTime.now().millisecondsSinceEpoch,
//         oldTx: false,
//       );

//       final txs = wallet.transactions.toList();
//       // final txs = walletBloc.state.wallet!.transactions.toList();
//       final idx = txs.indexWhere((element) => element.txid == newTx.txid);
//       if (idx != -1) {
//         txs.removeAt(idx);
//         txs.insert(idx, newTx);
//       } else
//         txs.add(newTx);
//       // txs.add(newTx);
//       final w = wallet.copyWith(transactions: txs);

//       return ((w, txid), null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while broadcasting transaction',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<Err?> broadcastTx({
//     required bdk.Transaction tx,
//     required bdk.Blockchain blockchain,
//   }) async {
//     try {
//       await blockchain.broadcast(tx);
//       return null;
//     } on Exception catch (e) {
//       return Err(
//         e.message,
//         title: 'Error occurred while broadcasting transaction',
//         solution: 'Please try again.',
//       );
//     }
//   }
// }
