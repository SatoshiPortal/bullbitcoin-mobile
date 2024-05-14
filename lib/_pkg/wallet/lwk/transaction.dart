import 'dart:typed_data';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class LWKTransactions {
  LWKTransactions({
    required NetworkRepository networkRepository,
    required SwapBoltz swapBoltz,
  })  : _networkRepository = networkRepository,
        _swapBoltz = swapBoltz;

  final NetworkRepository _networkRepository;
  final SwapBoltz _swapBoltz;

  Transaction addOutputAddresses(Address newAddress, Transaction tx) {
    final outAddrs = List<Address>.from(tx.outAddrs);
    final index = outAddrs.indexWhere(
      (address) => address == newAddress,
    );

    if (index != -1) {
      final updatedAddress = outAddrs.removeAt(index);
      // (state: newAddress.state);
      // outAddrs[index] = newAddress;
      outAddrs.insert(index, updatedAddress.copyWith(state: newAddress.state));
    } else {
      outAddrs.add(newAddress);
      // print(outAddrs);
    }
    return tx.copyWith(outAddrs: outAddrs);
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

  /// If given swap is expired,
  ///   - check if the swapTx has been refunded
  ///   - If yes, remove it from wallet.swaps
  ///   - if not, add it to the list of swaps to refund and return
  /// If not,
  ///   - update txid of wallet.swaps with swapTx.txid
  (({Wallet wallet})?, Err?) updateSwapTxs({
    required SwapTx swapTx,
    required Wallet wallet,
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

    final swapsToDelete = <SwapTx>[
      for (final s in swapTxs)
        if (s.paidSubmarine() ||
            s.settledReverse() ||
            s.settledSubmarine() ||
            s.expiredReverse())
          s,
    ];

    for (final s in swapsToDelete)
      if (swapsToDelete.any((_) => _.id == s.id))
        swapTxs.removeWhere((_) => _.id == s.id);

    final updatedWallet = wallet.copyWith(swaps: swapTxs);

    return ((wallet: updatedWallet), null);
  }

  Future<(({Wallet wallet, SwapTx swapsToDelete})?, Err?)> mergeSwapTxIntoTx({
    required Wallet wallet,
    required SwapTx swapTx,
  }) async {
    try {
      final txs = wallet.transactions.toList();
      final swaps = wallet.swaps;
      final updatedSwaps = swaps.toList();
      // final swapsToDelete = <SwapTx>[];

      final idx = txs.indexWhere((_) => _.txid == swapTx.txid);
      if (idx == -1) return (null, Err('No new matching tx'));

      final newTx = txs[idx].copyWith(
        swapTx: swapTx,
        isSwap: true,
      );
      txs[idx] = newTx;

      final swapToDelete = swaps.firstWhere((_) => _.id == swapTx.id);
      // swapsToDelete.add(swapToDelete);
      updatedSwaps.removeWhere((_) => _.id == swapTx.id);

      final updatedWallet = wallet.copyWith(
        transactions: txs,
        swaps: updatedSwaps,
      );

      return ((wallet: updatedWallet, swapsToDelete: swapToDelete), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  // Future<(Wallet?, Err?)> getTransactionsNew({
  //   required Wallet wallet,
  //   required bdk.Wallet bdkWallet,
  // }) async {
  //   try {
  //     final storedTxs = wallet.transactions;
  //     final unsignedTxs = wallet.unsignedTxs;
  //     final bdkNetwork = wallet.getBdkNetwork();
  //     if (bdkNetwork == null) throw 'No bdkNetwork';

  //     final txs = await bdkWallet.listTransactions(true);
  //     // final x = bdk.TxBuilderResult();

  //     if (txs.isEmpty) return (wallet, null);

  //     final List<Transaction> transactions = [];

  //     for (final tx in txs) {
  //       String? label;

  //       final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
  //       final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

  //       Transaction? storedTx;
  //       if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
  //       if (idxUnsignedTx != -1) {
  //         if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
  //       }
  //       var txObj = Transaction(
  //         txid: tx.txid,
  //         received: tx.received,
  //         sent: tx.sent,
  //         fee: tx.fee ?? 0,
  //         height: tx.confirmationTime?.height ?? 0,
  //         timestamp: tx.confirmationTime?.timestamp ?? 0,
  //         bdkTx: tx,
  //         rbfEnabled: storedTx?.rbfEnabled ?? false,
  //         outAddrs: storedTx?.outAddrs ?? [],
  //       );

  //       if (storedTxIdx != -1 &&
  //           storedTxs[storedTxIdx].label != null &&
  //           storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

  //       final SerializedTx sTx = SerializedTx.fromJson(
  //         jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
  //       );

  //       const hexDecoder = HexDecoder();
  //       final outputs = sTx.output;

  //       for (final output in outputs!) {
  //         final scriptPubKey = await bdk.Script.create(
  //           hexDecoder.convert(output.scriptPubkey!) as Uint8List,
  //         );

  //         final addressStruct = await bdk.Address.fromScript(
  //           scriptPubKey,
  //           bdkNetwork,
  //         );

  //         final existing = wallet.findAddressInWallet(addressStruct.toString());
  //         if (existing != null) {
  //           // txObj.outAddrs.add(existing);
  //           if (existing.label == null && existing.label!.isEmpty)
  //             txObj = addOutputAddresses(existing.copyWith(label: label), txObj);
  //           else {
  //             label ??= existing.label;
  //             txObj = addOutputAddresses(existing, txObj);
  //           }
  //         } else {
  //           if (txObj.isReceived()) {
  //             // AddressKind.deposit should exist in the addressBook
  //             // may not be applicable for payjoin
  //           } else {
  //             // AddressKind.external wont exist for imported wallets and must be added here
  //             // AddressKind.change should exist in the addressBook
  //             final (externalAddress, _) = await WalletAddress().addAddressToWallet(
  //               address: (null, addressStruct.toString()),
  //               wallet: wallet,
  //               spentTxId: tx.txid,
  //               kind: AddressKind.external,
  //               state: AddressStatus.used,
  //               spendable: false,
  //               label: label,
  //             );
  //             txObj = addOutputAddresses(externalAddress, txObj);
  //           }
  //         }
  //       }

  //       if (txObj.isReceived()) {
  //         final recipients = txObj.outAddrs
  //             .where((element) => element.kind == AddressKind.deposit)
  //             .toList()
  //             .map((e) => e.address);
  //         // may break for payjoin

  //         txObj = txObj.copyWith(
  //           toAddress: recipients.toString(),
  //         );
  //       } else {
  //         final recipients = txObj.outAddrs
  //             .where((element) => element.kind == AddressKind.external)
  //             .toList()
  //             .map((e) => e.address);
  //         txObj = txObj.copyWith(
  //           toAddress: recipients.toString(),
  //         );
  //       }

  //       transactions.add(txObj.copyWith(label: label));
  //     }

  //     final w = wallet.copyWith(
  //       transactions: transactions,
  //       unsignedTxs: unsignedTxs,
  //     );

  //     return (w, null);
  //   } on Exception catch (e) {
  //     return (
  //       null,
  //       Err(
  //         e.message,
  //         title: 'Error occurred while getting transactions',
  //         solution: 'Please try again.',
  //       )
  //     );
  //   }
  // }

  Future<(Wallet?, Err?)> getLiquidTransactions({
    required Wallet wallet,
    required lwk.Wallet lwkWallet,
  }) async {
    try {
      final storedTxs = wallet.transactions.toList();
      final unsignedTxs = wallet.unsignedTxs.toList();

      final txs = await lwkWallet.txs();
      const bKey = ''; // await lwkWallet.blindingKey();

      if (txs.isEmpty) return (wallet, null);

      final List<Transaction> transactions = [];
      final lwkNetwork = wallet.network == BBNetwork.Mainnet
          ? lwk.Network.mainnet
          : lwk.Network.testnet;

      for (final tx in txs) {
        // String? label;

        final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
        final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

        Transaction? storedTx;
        if (storedTxIdx != -1) storedTx = storedTxs[storedTxIdx];
        if (idxUnsignedTx != -1) {
          if (tx.txid == unsignedTxs[idxUnsignedTx].txid)
            unsignedTxs.removeAt(idxUnsignedTx);
        }
        final assetID = wallet.network == BBNetwork.Mainnet
            ? lwk.lBtcAssetId
            : lwk.lTestAssetId;
        final balances = tx.balances;
        final finalBalance = balances
            .where((e) => e.assetId == assetID)
            .map((e) => e.value)
            .first;

        final List<Future<Address>>? outAddressFuture;
        final List<Address>? outAddressFinal;
        if (storedTx?.outAddrs == null) {
          outAddressFuture = tx.outputs
              .map(
                (e) async =>
                    convertOutToAddress(tx, e, lwkNetwork, bKey, finalBalance),
              )
              .toList();
          outAddressFinal = await Future.wait(outAddressFuture);
        } else {
          outAddressFinal = storedTx?.outAddrs;
        }

        final txObj = Transaction(
          txid: tx.txid,
          received: tx.kind == 'outgoing' ? 0 : finalBalance,
          sent: tx.kind == 'outgoing' ? -finalBalance : 0,
          fee: tx.fee,
          height: tx.height,
          timestamp: tx.timestamp,
          rbfEnabled: false,
          outAddrs: outAddressFinal!,
          isLiquid: true,
          swapTx: storedTx?.swapTx,
          isSwap: storedTx?.isSwap ?? false,
        );
        transactions.add(txObj);
      }

      for (final tx in storedTxs) {
        if (transactions.any((t) => t.txid == tx.txid)) continue;
        transactions.add(tx);
      }

      // Future.delayed(const Duration(milliseconds: 200));
      final w = wallet.copyWith(
        transactions: transactions,
        unsignedTxs: unsignedTxs,
      );

      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while getting transactions',
          solution: 'Please try again.',
        )
      );
    }
  }

  // TODO: This is partially done function
  Future<Address> convertOutToAddress(
    lwk.Tx tx,
    lwk.TxOut e,
    lwk.Network lwkNetwork,
    String bKey,
    int finalBalance,
  ) async {
    if (tx.kind == 'outgoing') {
      final addr = await lwk.Address.addressFromScript(
        network: lwkNetwork,
        script: e.scriptPubkey,
        blindingKey: '',
      );
      return Address(
        address: addr.confidential,
        standard: addr.standard,
        kind: AddressKind.external,
        state: AddressStatus.active,
        isLiquid: true,
      );
    } else {
      if (e.unblinded.value == finalBalance) {
        final addr = await lwk.Address.addressFromScript(
          network: lwkNetwork,
          script: e.scriptPubkey,
          blindingKey: bKey,
        );
        return Address(
          address: addr.confidential,
          standard: addr.standard,
          kind: AddressKind.deposit,
          state: AddressStatus.active,
          isLiquid: true,
        );
      } else {
        final addr = await lwk.Address.addressFromScript(
          network: lwkNetwork,
          script: e.scriptPubkey,
          blindingKey: '',
        );
        return Address(
          address: addr.confidential,
          standard: addr.standard,
          kind: AddressKind.external,
          state: AddressStatus.used,
          isLiquid: true,
        );
      }
    }
  }

  Future<((Transaction?, int?, String)?, Err?)> buildLiquidTx({
    required Wallet wallet,
    required lwk.Wallet lwkWallet,
    required String address,
    required int? amount,
    required bool sendAllCoin,
    required double feeRate,
  }) async {
    try {
      // final isMainnet = wallet.network == BBNetwork.LMainnet;
      // if (isMainnet != isLiquidMainnetAddress(address)) {
      //   return (
      //     null,
      //     Err('Invalid Address. Network Mismatch!'),
      //   );
      // }
      // final pset = await lwkWallet.build(sats: amount ?? 0, outAddress: address, absFee: feeRate);
      final pset = await lwkWallet.buildLbtcTx(
        sats: amount ?? 0,
        outAddress: address,
        feeRate: feeRate * 1000.0,
      );
      // pubWallet.sign(network: wallet.network == BBNetwork.LMainnet ? lwk.Network.Mainnet : lwk.Network.Testnet , pset: pset, mnemonic: mnemonic)
      final decoded = await lwkWallet.decodeTx(pset: pset);

      final Transaction tx = Transaction(
        txid: '',
        received: 0,
        sent: amount ?? 0,
        fee: decoded.absoluteFees,
        height: 0,
        timestamp: 0,
        label: '',
        toAddress: address,
        outAddrs: [],
        psbt: pset,
        isLiquid: true,
      );
      return ((tx, decoded.absoluteFees, pset), null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while building transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Uint8List?, Err?)> signTx({
    required String pset,
    required lwk.Wallet lwkWallet,
    required Wallet wallet,
    required Seed seed,
  }) async {
    try {
      final signedTx = await lwkWallet.signTx(
        network: wallet.network == BBNetwork.Mainnet
            ? lwk.Network.mainnet
            : lwk.Network.testnet,
        pset: pset,
        mnemonic: seed.mnemonic,
      );
      return (signedTx, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while signing transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<((Wallet, String)?, Err?)> broadcastLiquidTxWithWallet({
    required Wallet wallet,
    required lwk.Wallet lwkWallet,
    required Transaction transaction,
    bool useOnlyLwk = true, // TODO: Remove this
  }) async {
    try {
      final (blockchain, err) = _networkRepository.liquidUrl;
      if (err != null) throw err;
      String txid;

      if (useOnlyLwk) {
        txid = await lwk.Wallet.broadcastTx(
          electrumUrl: blockchain!,
          txBytes: transaction.pset!,
        );
      } else {
        if (!transaction.isSwap) {
          txid = await lwk.Wallet.broadcastTx(
            electrumUrl: blockchain!,
            txBytes: transaction.pset!,
          );
        } else {
          final (txxid, errBroadcast) = await _swapBoltz.broadcastV2(
            swapTx: transaction.swapTx!,
            signedBytes: transaction.pset!,
          );
          if (errBroadcast != null) throw errBroadcast;
          txid = txxid!;
        }
      }

      final newTx = transaction.copyWith(
        txid: txid,
        broadcastTime: DateTime.now().millisecondsSinceEpoch,
        swapTx: transaction.swapTx?.copyWith(txid: txid),
      );

      final txs = wallet.transactions.toList();
      // final txs = walletBloc.state.wallet!.transactions.toList();
      final idx = txs.indexWhere((element) => element.txid == newTx.txid);
      if (idx != -1) {
        txs.removeAt(idx);
        txs.insert(idx, newTx);
      } else
        txs.add(newTx);
      final w = wallet.copyWith(transactions: txs);

      return ((w, txid), null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while broadcasting transaction',
          solution: 'Please try again.',
        )
      );
    }
  }
}
