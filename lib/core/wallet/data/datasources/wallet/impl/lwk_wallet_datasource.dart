import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:flutter/material.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkWalletDatasource implements WalletDatasource {
  @visibleForTesting
  final Map<String, int> syncExecutions = {};
  final Map<String, Future<void>> _activeSyncs;
  final StreamController<String> _walletSyncStartedController;
  final StreamController<String> _walletSyncFinishedController;

  LwkWalletDatasource()
      : _activeSyncs = {},
        _walletSyncStartedController = StreamController<String>.broadcast(),
        _walletSyncFinishedController = StreamController<String>.broadcast();

  Stream<String> get walletSyncStartedStream =>
      _walletSyncStartedController.stream;
  Stream<String> get walletSyncFinishedStream =>
      _walletSyncFinishedController.stream;

  bool get isAnyWalletSyncing => _activeSyncs.isNotEmpty;

  Future<BalanceModel> getBalance({
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final balances = await lwkWallet.balances();

    final lBtcAssetBalance = balances.firstWhere((balance) {
      final assetId = _lBtcAssetId(
        wallet.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
      );
      return balance.assetId == assetId;
    }).value;

    final balance = BalanceModel(
      confirmedSat: BigInt.from(lBtcAssetBalance),
      immatureSat: BigInt.zero,
      trustedPendingSat: BigInt.zero,
      untrustedPendingSat: BigInt.zero,
      spendableSat: BigInt.from(lBtcAssetBalance),
      totalSat: BigInt.from(lBtcAssetBalance),
    );

    return balance;
  }

  @override
  Future<void> sync({
    required WalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) {
    // putIfAbsent ensures only one sync starts for each wallet ID,
    //  all others await the same Future.
    debugPrint('Sync requested for wallet: ${wallet.id}');
    return _activeSyncs.putIfAbsent(wallet.id, () async {
      try {
        debugPrint('New sync started for wallet: ${wallet.id}');
        // Notify that the wallet is syncing through a stream for other
        // parts of the app to listen to so they can show a syncing indicator
        _walletSyncStartedController.add(wallet.id);
        // Increment the sync execution count for this wallet for testing purposes
        syncExecutions.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);
        final lwkWallet = await _createPublicWallet(wallet);
        await lwkWallet.sync(
          electrumUrl: electrumServer.url,
          validateDomain: electrumServer.validateDomain,
        );
        debugPrint('Sync completed for wallet: ${wallet.id}');
      } catch (e) {
        debugPrint('Sync error for wallet ${wallet.id}: $e');
        rethrow;
      } finally {
        // Notify that the wallet has been synced to other parts of the app
        // by pushing the wallet ID to the stream
        _walletSyncFinishedController.add(wallet.id);
        // Remove the sync so future syncs can be triggered
        _activeSyncs.remove(wallet.id);
      }
    });
  }

  /* Start UtxoDatasource methods */
  @override
  Future<List<UtxoModel>> getUtxos({
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final utxos = await lwkWallet.utxos();

    final unspent = utxos.map((utxo) {
      return UtxoModel(
        txId: utxo.outpoint.txid,
        vout: utxo.outpoint.vout,
        value: utxo.unblinded.value,
        scriptPubkey: Uint8ListX.fromHexString(utxo.scriptPubkey),
      );
    }).toList();

    return unspent;
  }
  /* End UtxoDatasource methods */

  /* Start AddressDatasource methods */
  @override
  Future<AddressModel> getNewAddress({
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final lastUnusedAddressInfo = await lwkWallet.addressLastUnused();

    // this method will always return an index so ! is safe
    // index will only be null when address is part of a TxOut
    final newIndex = lastUnusedAddressInfo.index! + 1;
    final addressInfo = await lwkWallet.address(index: newIndex);

    final address = LiquidAddressModel(
      index: addressInfo.index!,
      standard: addressInfo.standard,
      confidential: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<AddressModel> getLastUnusedAddress({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final addressInfo = await lwkWallet.addressLastUnused();

    final address = LiquidAddressModel(
      index: addressInfo.index!,
      standard: addressInfo.standard,
      confidential: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<AddressModel> getAddressByIndex(
    int index, {
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final addressInfo = await lwkWallet.address(index: index);

    final address = LiquidAddressModel(
      index: addressInfo.index!,
      standard: addressInfo.standard,
      confidential: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<List<AddressModel>> getReceiveAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);

    final addresses = <LiquidAddressModel>[];
    for (int i = offset; i < offset + limit; i++) {
      final addressInfo = await lwkWallet.address(index: i);
      final address = LiquidAddressModel(
        index: addressInfo.index!,
        standard: addressInfo.standard,
        confidential: addressInfo.confidential,
      );
      addresses.add(address);
    }
    return addresses;
  }

  @override
  Future<List<AddressModel>> getChangeAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    // Lwk does not support change addresses at the moment
    // so we return an empty list
    return [];
  }

  @override
  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final txs = await lwkWallet.txs();
    final txOutputLists = txs.map((tx) => tx.outputs).toList();

    final outputs = txOutputLists.expand((list) => list).toList();
    if (outputs.isEmpty) {
      return false;
    }

    final isUsed = await Future.any(
      outputs.map((output) async {
        return output.address.confidential == address ||
            output.address.standard == address;
      }),
    );

    return isUsed;
  }

  @override
  Future<BigInt> getAddressBalanceSat(
    String address, {
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final utxos = await lwkWallet.utxos();

    BigInt balance = BigInt.zero;

    // return balance;
    for (final utxo in utxos) {
      final assetId = _lBtcAssetId(
        Network.fromEnvironment(isTestnet: wallet.isTestnet, isLiquid: true),
      );
      if (utxo.unblinded.asset != assetId) {
        continue;
      }

      if (utxo.address.confidential == address ||
          utxo.address.standard == address) {
        balance += utxo.unblinded.value;
      }
    }

    return balance;
  }
  /* End AddressDatasource methods */

  String _lBtcAssetId(Network network) {
    return network == Network.liquidTestnet
        ? lwk.lTestAssetId
        : lwk.lBtcAssetId;
  }

  /* Start TransactionDatasource methods */
  @override
  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final transactions = await lwkWallet.txs();
    if (toAddress != null && toAddress.isNotEmpty) {
      transactions.removeWhere(
        (tx) => tx.outputs.every(
          (output) =>
              output.address.standard != toAddress &&
              output.address.confidential != toAddress,
        ),
      );
    }
    final List<WalletTransactionModel> walletTxs = [];
    for (final tx in transactions) {
      final balances = tx.balances;
      final finalBalance = balances
              .where(
                (e) =>
                    e.assetId ==
                    _lBtcAssetId(
                      wallet.isTestnet
                          ? Network.liquidTestnet
                          : Network.liquidMainnet,
                    ),
              )
              .map((e) => e.value)
              .firstOrNull ??
          0;
      final isIncoming = tx.kind != 'outgoing';
      // final confirmationTime = tx.timestamp ?? 0;
      final walletTx = WalletTransactionModel.liquid(
        txId: tx.txid,
        isIncoming: isIncoming,
        amountSat: finalBalance.abs(),
        feeSat: tx.fee.toInt(),
        confirmationTimestamp: tx.timestamp,
      );
      walletTxs.add(walletTx);
    }
    return walletTxs;
  }
  /* End TransactionDatasource methods */

  Future<String> buildPset({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    required WalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    if (networkFee.isAbsolute) {
      throw Exception('Absolute fee is not supported for liquid yet!');
    }
    debugPrint(
      networkFee.value.toDouble().toString(),
    );
    final pset = await lwkWallet.buildLbtcTx(
      sats: BigInt.from(amountSat ?? 0),
      outAddress: address,
      feeRate: networkFee.value.toDouble() * 1000,
      drain: drain,
    );
    final decoded = await lwkWallet.decodeTx(pset: pset);
    debugPrint(
      decoded.absoluteFees.toString(),
    );
    return pset;
  }

  Future<Uint8List> signPset(
    String pset, {
    required PrivateLwkWalletModel wallet,
  }) async {
    final lwkWallet = await _createPrivateWallet(wallet);

    final signedBytes = await lwkWallet.signTx(
      network: wallet.isTestnet ? lwk.Network.testnet : lwk.Network.mainnet,
      pset: pset,
      mnemonic: wallet.mnemonic,
    );

    return signedBytes;
  }

  Future<String> _getDbPath(String dbName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$dbName';
  }

  Future<lwk.Wallet> _createPublicWallet(WalletModel walletModel) async {
    if (walletModel is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final network =
        walletModel.isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = lwk.Descriptor(
      ctDescriptor: walletModel.combinedCtDescriptor,
    );
    final dbPath = await _getDbPath(walletModel.dbName);
    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return wallet;
  }

  Future<lwk.Wallet> _createPrivateWallet(
    WalletModel walletModel,
  ) async {
    if (walletModel is! PrivateLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final network =
        walletModel.isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = await lwk.Descriptor.newConfidential(
      mnemonic: walletModel.mnemonic,
      network: network,
    );
    final dbPath = await _getDbPath(walletModel.dbName);

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return wallet;
  }
}

extension NetworkX on Network {
  lwk.Network get lwkNetwork {
    switch (this) {
      case Network.liquidMainnet:
        return lwk.Network.mainnet;
      case Network.liquidTestnet:
        return lwk.Network.testnet;
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        throw UnsupportedLwkNetworkException(
          'Bitcoin network is not supported by LWK',
        );
    }
  }
}

class UnsupportedLwkNetworkException implements Exception {
  final String message;

  UnsupportedLwkNetworkException(this.message);
}
