import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/liquid/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:lwk/lwk.dart' as lwk;

class LwkWalletRepositoryImpl
    implements WalletRepository, LiquidWalletRepository {
  final lwk.Network _network;
  final lwk.Wallet _wallet;

  LwkWalletRepositoryImpl({
    required lwk.Network network,
    required lwk.Wallet wallet,
  })  : _network = network,
        _wallet = wallet;

  static Future<LwkWalletRepositoryImpl> public({
    required String ctDescriptor,
    required String dbPath,
    required bool isTestnet,
    required ElectrumServer electrumServer,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = lwk.Descriptor(
      ctDescriptor: ctDescriptor,
    );

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return LwkWalletRepositoryImpl(
      network: network,
      wallet: wallet,
    );
  }

  static Future<LwkWalletRepositoryImpl> private({
    required String mnemonic,
    required String dbPath,
    required bool isTestnet,
    required ElectrumServer electrumServer,
  }) async {
    final network = isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

    final descriptor = await lwk.Descriptor.newConfidential(
      mnemonic: mnemonic,
      network: network,
    );

    final wallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return LwkWalletRepositoryImpl(
      network: network,
      wallet: wallet,
    );
  }

  @override
  Future<Balance> getBalance() async {
    final balances = await _wallet.balances();

    final lBtcAssetBalance = balances.firstWhere((balance) {
      return balance.assetId == _lBtcAssetId;
    }).value;

    final balance = Balance(
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
  Future<Address> getNewAddress() async {
    final lastUnusedAddressInfo = await _wallet.addressLastUnused();
    // this method will always return an index so ! is safe
    // index will only be null when address is part of a TxOut
    final newIndex = lastUnusedAddressInfo.index! + 1;
    final addressInfo = await _wallet.address(index: newIndex);

    final address = Address.liquid(
      index: addressInfo.index!,
      standard: addressInfo.standard,
      confidential: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<Address> getAddressByIndex(int index) async {
    final addressInfo = await _wallet.address(index: index);

    final address = Address.liquid(
      index: addressInfo.index!,
      standard: addressInfo.standard,
      confidential: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<Address> getLastUnusedAddress() async {
    final addressInfo = await _wallet.addressLastUnused();

    final address = Address.liquid(
      index: addressInfo.index!,
      standard: addressInfo.standard,
      confidential: addressInfo.confidential,
    );

    return address;
  }

  @override
  Future<void> sync({required ElectrumServer electrumServer}) async {
    await _wallet.sync(
      electrumUrl: electrumServer.url,
      validateDomain: electrumServer.validateDomain,
    );
  }

  @override
  Future<BigInt> getAddressBalanceSat(String address) async {
    final utxos = await _wallet.utxos();

    BigInt balance = BigInt.zero;

    // return balance;
    for (final utxo in utxos) {
      if (utxo.unblinded.asset != _lBtcAssetId) {
        continue;
      }

      if (utxo.address.confidential == address ||
          utxo.address.standard == address) {
        balance += utxo.unblinded.value;
      }
    }

    return balance;
  }

  @override
  Future<bool> isAddressUsed(String address) async {
    final txs = await _wallet.txs();
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
  Future<List<Utxo>> listUnspent() async {
    final utxos = await _wallet.utxos();

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

  String get _lBtcAssetId =>
      _network == lwk.Network.testnet ? lwk.lTestAssetId : lwk.lBtcAssetId;

  @override
  Future<List<BaseWalletTransaction>> getTransactions(String walletId) async {
    final transactions = await _wallet.txs();
    final List<BaseWalletTransaction> walletTxs = [];
    final assetID =
        _network == lwk.Network.mainnet ? lwk.lBtcAssetId : lwk.lTestAssetId;

    for (final tx in transactions) {
      // check if the transaction is
      final balances = tx.balances;
      final finalBalance = balances
              .where((e) => e.assetId == assetID)
              .map((e) => e.value)
              .firstOrNull ??
          0;
      final type = tx.kind == 'outgoing' ? TxType.send : TxType.receive;
      final confirmationTime = tx.timestamp ?? 0;
      final walletTx = BaseWalletTransaction(
        walletId: walletId,
        network: _network == lwk.Network.mainnet
            ? Network.liquidMainnet
            : Network.liquidTestnet,
        txid: tx.txid,
        type: type,
        amount: finalBalance,
        confirmationTime: confirmationTime != 0
            ? DateTime.fromMillisecondsSinceEpoch(confirmationTime * 1000)
            : null,
      );
      walletTxs.add(walletTx);
    }
    return walletTxs;
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
