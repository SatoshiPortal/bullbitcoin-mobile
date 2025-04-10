import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/address/data/datasources/address_datasource.dart';
import 'package:bb_mobile/core/address/data/models/address_model.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utxo/data/datasources/utxo_datasource.dart';
import 'package:bb_mobile/core/utxo/data/models/utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/private_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet_transaction/data/datasources/wallet_transaction_datasource.dart';
import 'package:bb_mobile/core/wallet_transaction/data/models/wallet_transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkWalletDatasource
    implements AddressDatasource, WalletTransactionDatasource, UtxoDatasource {
  LwkWalletDatasource();
  final Map<String, Completer<void>> _activeSyncs = {};

  void completeActiveSyncForWallet(String walletDb) {
    if (_activeSyncs.containsKey(walletDb)) {
      _activeSyncs[walletDb]?.complete();
      _activeSyncs.remove(walletDb);
    }
  }

  Future<void>? getActiveSyncForWallet(String walletDb) =>
      _activeSyncs[walletDb]?.future;

  Future<String> _getDbPath(String dbName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$dbName';
  }

  Future<lwk.Wallet> _createPublicWallet(PublicWalletModel walletModel) async {
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
    PrivateWalletModel walletModel,
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

  Future<BalanceModel> getBalance({
    required PublicLwkWalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final balances = await lwkWallet.balances();

    final lBtcAssetBalance = balances.firstWhere((balance) {
      final assetId = _lBtcAssetId(
        Network.fromEnvironment(isTestnet: wallet.isTestnet, isLiquid: true),
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
    required PublicWalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) async {
    if (_activeSyncs[wallet.dbName]?.future != null ||
        _activeSyncs.containsKey(wallet.dbName)) {
      return _activeSyncs[wallet.dbName]!.future;
    }

    _activeSyncs[wallet.dbName] = Completer<void>();

    try {
      final lwkWallet = await _createPublicWallet(wallet);
      await lwkWallet.sync(
        electrumUrl: electrumServer.url,
        validateDomain: electrumServer.validateDomain,
      );
      _activeSyncs[wallet.dbName]?.complete();
    } catch (e) {
      _activeSyncs[wallet.dbName]?.completeError(e);
      debugPrint(e.toString());
      rethrow;
    } finally {
      _activeSyncs.remove(wallet.dbName);
    }
  }

  /* Start UtxoDatasource methods */
  @override
  Future<List<UtxoModel>> getUtxos({
    required PublicWalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(wallet);
    final utxos = await lwkWallet.utxos();

    final unspent = utxos.map((utxo) {
      return UtxoModel(
        txId: utxo.outpoint.txid,
        vout: utxo.outpoint.vout,
        value: utxo.unblinded.value,
        // TODO: The following conversion to Uint8List is probably not correct
        //  but we don't need it for now.
        scriptPubkey: Uint8List.fromList(utxo.scriptPubkey.codeUnits),
      );
    }).toList();

    return unspent;
  }
  /* End UtxoDatasource methods */

  /* Start AddressDatasource methods */
  @override
  Future<AddressModel> getNewAddress({
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicWalletModel wallet,
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
    required PublicLwkWalletModel wallet,
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
