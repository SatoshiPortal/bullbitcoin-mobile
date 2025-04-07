import 'dart:typed_data';

import 'package:bb_mobile/core/address/data/datasources/address_datasource.dart';
import 'package:bb_mobile/core/address/data/models/address_model.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/private_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkWalletDatasource implements AddressDatasource {
  const LwkWalletDatasource();

  Future<String> _getDbPath(String dbName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$dbName';
  }

  Future<lwk.Wallet> _createPublicWallet({
    required String ctDescriptor,
    required String dbName,
    required bool isTestnet,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = lwk.Descriptor(
      ctDescriptor: ctDescriptor,
    );
    final dbPath = await _getDbPath(dbName);
    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return wallet;
  }

  Future<lwk.Wallet> _createPrivateWallet({
    required String mnemonic,
    required String dbName,
    required bool isTestnet,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = await lwk.Descriptor.newConfidential(
      mnemonic: mnemonic,
      network: network,
    );
    final dbPath = await _getDbPath(dbName);

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
    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
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

  Future<void> sync({
    required PublicLwkWalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) async {
    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
    await lwkWallet.sync(
      electrumUrl: electrumServer.url,
      validateDomain: electrumServer.validateDomain,
    );
  }

  Future<List<Utxo>> listUnspent({
    required PublicLwkWalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
    final utxos = await lwkWallet.utxos();

    final unspent = utxos.map((utxo) {
      return Utxo(
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

  /* Start AddressDatasource methods */
  @override
  Future<AddressModel> getNewAddress({
    required PublicWalletModel wallet,
  }) async {
    if (wallet is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
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
    if (wallet is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
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
    if (wallet is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
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
    if (wallet is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );

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
    if (wallet is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
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
    if (wallet is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }

    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
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

  /*
  Future<List<WalletTransactionModel>> getTransactions(
    String walletId,
    Network network, {
    required PublicLwkWalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
    final transactions = await lwkWallet.txs();
    final List<WalletTransactionModel> walletTxs = [];
    for (final tx in transactions) {
      // check if the transaction is
      final balances = tx.balances;
      final finalBalance = balances
              .where((e) => e.assetId == _lBtcAssetId(network))
              .map((e) => e.value)
              .firstOrNull ??
          0;
      final type = tx.kind == 'outgoing' ? TxType.send : TxType.receive;
      // final confirmationTime = tx.timestamp ?? 0;
      final walletTx = WalletTransactionModel(
        network: network,
        txId: tx.txid,
        amount: finalBalance.abs(),
        isIncoming: type == TxType.receive,
        fees: tx.fee.toInt(),
      );
      walletTxs.add(walletTx);
    }
    return walletTxs;
  }*/

  Future<String> buildPset({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    required PublicLwkWalletModel wallet,
  }) async {
    final lwkWallet = await _createPublicWallet(
      ctDescriptor: wallet.combinedCtDescriptor,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );
    if (networkFee.isAbsolute) {
      throw Exception('Absolute fee is not supported for liquid yet!');
    }
    final pset = await lwkWallet.buildLbtcTx(
      sats: BigInt.from(amountSat ?? 0),
      outAddress: address,
      feeRate: networkFee.value.toDouble(),
      drain: drain,
    );
    return pset;
  }

  Future<Uint8List> signPset(
    String pset, {
    required PrivateLwkWalletModel wallet,
  }) async {
    final lwkWallet = await _createPrivateWallet(
      mnemonic: wallet.mnemonic,
      dbName: wallet.dbName,
      isTestnet: wallet.isTestnet,
    );

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
