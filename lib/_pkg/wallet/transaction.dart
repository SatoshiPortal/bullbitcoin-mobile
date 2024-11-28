import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
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
    int? absFee,
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
            absFee: absFee,
          );
          if (err != null) throw err;
          final (tx, feeAmt, psbt) = buildResp!;
          if (!wallet.watchOnly()) {
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
          } else {
            final txs = wallet.transactions.toList();
            txs.add(tx!);
            final (w, errAdd) =
                await addUnsignedTxToWallet(transaction: tx, wallet: wallet);
            if (errAdd != null) throw errAdd;
            return ((w, tx, feeAmt), null);
          }

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
            absFee: absFee,
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
    bool useOnlyLwk = false,
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
            note: note,
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
            useOnlyLwk: useOnlyLwk,
            note: note,
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
        spendable: false,
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

  /// Takes in swapTx and Wallet
  /// Updates all references to swapTx in Wallet
  /// wallet.swaps : find existing swap and update
  /// wallet.transactions : find existing transaction with swap and update OR add swap to an existing transaction
  ///
  (({Wallet wallet})?, Err?) updateSwapTxs({
    required SwapTx swapTx,
    required Wallet wallet,
    bool deleteIfFailed = false,
  }) {
    final swaps = wallet.swaps;
    final idx = swaps.indexWhere((e) => e.id == swapTx.id);
    if (idx == -1) return (null, Err('No swapTx found'));
    final storedSwap = swaps[idx];

    final swapTxs = List<SwapTx>.from(swaps);

    final updatedSwapTx = storedSwap.copyWith(
      status: swapTx.status,
      claimTxid: storedSwap.claimTxid ?? swapTx.claimTxid,
      lockupTxid: storedSwap.lockupTxid ?? swapTx.lockupTxid,
      lnSwapDetails: swapTx.isLnSwap()
          ? storedSwap.lnSwapDetails!.copyWith(
              keyIndex: storedSwap.lnSwapDetails!.keyIndex,
            )
          : null,
      chainSwapDetails: swapTx.isChainSwap()
          ? storedSwap.chainSwapDetails!.copyWith(
              refundKeyIndex: swapTx.chainSwapDetails!.refundKeyIndex,
              claimKeyIndex: swapTx.chainSwapDetails!.claimKeyIndex,
            )
          : null,
      completionTime: swapTx.completionTime,
    );
    swapTxs[idx] = updatedSwapTx;
    final txs = wallet.transactions.toList();
    // lockup submarine / server claim
    // lockup chain.self / self claim
    // lockup chain.send / server claim (end user got paid)

    // claim reverse / server lockup
    // claim chain.self / self lockup
    // claim chain.receive / server lockup (user made payment)

    // new reverse swaps need to create a transaction.txid with the swap.id

    if (updatedSwapTx.isSubmarine()) {
      final idx = txs.indexWhere((e) => e.txid == updatedSwapTx.lockupTxid);

      if (idx != -1) {
        final updatedTx = txs[idx].copyWith(
          swapTx: updatedSwapTx,
          isSwap: true,
          label: swapTx.label,
        );
        txs[idx] = updatedTx;
      }
    }
    if (updatedSwapTx.paidReverse()) {
      // liquid is claimed at paid status
      // while this swapTx is paid, this function is called right after it is claimed
      // so here we will have an updatedSwap.claimTxid for Liquid
      // new reverse swaps need to create a transaction.txid with the swap.id
      final idx = txs.indexWhere((e) => e.txid == updatedSwapTx.id);

      if (idx == -1) {
        final newTx = updatedSwapTx.toNewTransaction();
        txs.add(newTx);
      } else {
        final updatedTx = txs[idx].copyWith(
          txid: updatedSwapTx.claimTxid ?? txs[idx].txid,
          swapTx: updatedSwapTx,
        );
        txs[idx] = updatedTx;
      }
    }
    if (updatedSwapTx.claimableReverse()) {
      // bitcoin is claimed at claimable status
      // while this swapTx is paid, this function is called right after it is claimed
      // so here we will have an updatedTxid for Bitcoin
      // since swap is past paid, it exists within a tx
      final txIdx = txs.indexWhere((e) => e.swapTx?.id == updatedSwapTx.id);

      if (txIdx != -1) {
        final updatedTx = txs[txIdx].copyWith(
          txid: updatedSwapTx.claimTxid ?? txs[txIdx].txid,
          swapTx: updatedSwapTx,
        );
        txs[txIdx] = updatedTx;
      }
    }
    if (updatedSwapTx.settledReverse()) {
      // settled reverse will match based on claimTxid
      final idx = txs.indexWhere((e) => e.txid == updatedSwapTx.claimTxid);
      if (idx != -1) {
        final updatedTx = txs[idx].copyWith(
          txid: updatedSwapTx.claimTxid!,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          swapTx: updatedSwapTx,
        );
        txs[idx] = updatedTx;
      }
    }
    // if (updatedSwapTx.isChainSend() || updatedSwapTx.isChainSelf()) {
    //   final txIdx = txs.indexWhere((_) => _.swapTx?.id == swapTx.id);

    //   if (txIdx != -1)
    //     txs[txIdx] = txs[txIdx].copyWith(
    //       swapTx: updatedSwapTx,
    //       label: swapTx.label,
    //       isSwap: true,
    //     );
    // }
    if (updatedSwapTx.paidOnchain() && updatedSwapTx.isChainReceive()) {
      final txIdx = txs.indexWhere((e) => e.txid == updatedSwapTx.lockupTxid);
      if (txIdx == -1) {
        final newTx = updatedSwapTx.toNewTransaction();
        txs.add(newTx);
      }
    }
    if ((updatedSwapTx.refundableOnchain() ||
            updatedSwapTx.refundedOnchain()) &&
        updatedSwapTx.isChainReceive()) {
      final txIdx = txs.indexWhere((e) => e.txid == updatedSwapTx.claimTxid);
      final txIdxById = txs.indexWhere((e) => e.txid == updatedSwapTx.id);

      if (txIdx == -1 && txIdxById == -1) {
        final newTx = updatedSwapTx.toNewTransaction();
        txs.add(newTx);
      } else {
        if (txIdx != -1) {
          txs[txIdx] = txs[txIdx].copyWith(
            swapTx: updatedSwapTx,
            txid: updatedSwapTx.claimTxid ?? txs[txIdx].txid,
            label: updatedSwapTx.label,
            isSwap: true,
          );
        }
      }
    }

    final txIdx = txs.indexWhere((e) => e.swapTx?.id == updatedSwapTx.id);
    if (txIdx != -1) {
      txs[txIdx] = txs[txIdx].copyWith(
        swapTx: updatedSwapTx,
        label: updatedSwapTx.label,
        isSwap: true,
      );
    } else {
      // This will match ChainSend and ChainSelf. (or) Create a separate if block to handle this
      // lockup tx's .swapTx is null and also isSwap set to false (happening sometime)
      final searchAgainIndex =
          txs.indexWhere((tx) => tx.toAddress == updatedSwapTx.scriptAddress);
      if (searchAgainIndex != -1) {
        txs[searchAgainIndex] = txs[searchAgainIndex].copyWith(
          swapTx: updatedSwapTx,
          label: updatedSwapTx.label,
          isSwap: true,
        );
      }
    }

    final swapIdx = swapTxs.indexWhere((e) => e.id == updatedSwapTx.id);
    if (swapIdx != -1) swapTxs[swapIdx] = updatedSwapTx;

    final closeSwap = swapTx.close();
    if (closeSwap) {
      swapTxs.removeWhere((e) => e.id == updatedSwapTx.id);
    }

    if (deleteIfFailed) {
      final swapsToDelete = <SwapTx>[
        for (final s in swapTxs)
          if (s.failed()) s,
      ];

      for (final s in swapsToDelete) {
        if (swapsToDelete.any((e) => e.id == s.id)) {
          swapTxs.removeWhere((e) => e.id == s.id);
        }
      }
    }

    final updatedWallet = wallet.copyWith(swaps: swapTxs, transactions: txs);

    return ((wallet: updatedWallet), null);
  }
}
