import 'dart:typed_data';

import 'package:bb_mobile/_core/data/datasources/wallets/bitcoin_wallet_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/wallets/payjoin_wallet_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/wallets/wallet_data_source.dart';
import 'package:bb_mobile/_core/data/models/address_model.dart';
import 'package:bb_mobile/_core/data/models/balance_model.dart';
import 'package:bb_mobile/_core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BdkWalletDataSourceImpl
    implements
        WalletDataSource,
        BitcoinWalletDataSource,
        PayjoinWalletDataSource {
  final bdk.Wallet _wallet;
  final bdk.Blockchain _blockchain;

  BdkWalletDataSourceImpl({
    required bdk.Wallet wallet,
    required bdk.Blockchain blockchain,
  })  : _wallet = wallet,
        _blockchain = blockchain;

  static Future<BdkWalletDataSourceImpl> public({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required String dbPath,
    required ElectrumServerModel electrumServer,
  }) async {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: externalDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: internalDescriptor,
      network: network,
    );

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: electrumServer.url,
          socks5: electrumServer.socks5,
          retry: electrumServer.retry,
          timeout: electrumServer.timeout,
          stopGap: BigInt.from(electrumServer.stopGap),
          validateDomain: electrumServer.validateDomain,
        ),
      ),
    );

    return BdkWalletDataSourceImpl(
      wallet: wallet,
      blockchain: blockchain,
    );
  }

  static Future<BdkWalletDataSourceImpl> private({
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required String dbPath,
    required ElectrumServerModel electrumServer,
  }) async {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final bdkMnemonic = await bdk.Mnemonic.fromString(mnemonic);
    final secretKey = await bdk.DescriptorSecretKey.create(
      network: network,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (scriptType) {
      case ScriptType.bip84:
        external = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip49:
        external = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip44:
        external = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
    }

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: electrumServer.url,
          socks5: electrumServer.socks5,
          retry: electrumServer.retry,
          timeout: electrumServer.timeout,
          stopGap: BigInt.from(electrumServer.stopGap),
          validateDomain: electrumServer.validateDomain,
        ),
      ),
    );

    return BdkWalletDataSourceImpl(
      wallet: wallet,
      blockchain: blockchain,
    );
  }

  @override
  Future<BalanceModel> getBalance() async {
    final balanceInfo = _wallet.getBalance();

    final balance = BalanceModel(
      confirmedSat: balanceInfo.confirmed,
      immatureSat: balanceInfo.immature,
      trustedPendingSat: balanceInfo.trustedPending,
      untrustedPendingSat: balanceInfo.untrustedPending,
      spendableSat: balanceInfo.spendable,
      totalSat: balanceInfo.total,
    );

    return balance;
  }

  @override
  Future<void> sync() async {
    await _wallet.sync(blockchain: _blockchain);
  }

  @override
  Future<AddressModel> getNewAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final address = AddressModel(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<AddressModel> getAddressByIndex(int index) async {
    final addressInfo = _wallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    final address = AddressModel(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<AddressModel> getLastUnusedAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final address = AddressModel(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<bool> isMine(Uint8List scriptBytes) async {
    final script = bdk.ScriptBuf(bytes: scriptBytes);
    final isMine = _wallet.isMine(script: script);

    return isMine;
  }

  @override
  Future<List<bdk.LocalUtxo>> listUnspent() async {
    // TODO: transform bdk.LocalUtxo to Utxo entity class and return a list of those
    return _wallet.listUnspent();
  }

  @override
  Future<String> buildPsbt({
    required String address,
    required BigInt amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
  }) async {
    final bdkAddress = await bdk.Address.fromString(
      s: address,
      network: _wallet.network(),
    );
    final script = bdkAddress.scriptPubkey();

    bdk.TxBuilder builder = bdk.TxBuilder().addRecipient(script, amountSat);
    if (absoluteFeeSat != null) {
      builder = builder.feeAbsolute(absoluteFeeSat);
    } else if (feeRateSatPerVb != null) {
      builder = builder.feeRate(feeRateSatPerVb);
    }

    final (psbt, _) = await builder.finish(_wallet);

    final isFinalized = await _wallet.sign(
      psbt: psbt,
      signOptions: const bdk.SignOptions(
        trustWitnessUtxo: true,
        allowAllSighashes: false,
        removePartialSigs: true,
        tryFinalize: true,
        signWithTapInternalKey: true,
        allowGrinding: false,
      ),
    );
    if (!isFinalized) {
      throw FailedToSignPsbtException('Failed to sign the transaction');
    }

    return psbt.asString();
  }

  @override
  Future<String> signPsbt(String psbt) async {
    final partiallySignedTransaction =
        await bdk.PartiallySignedTransaction.fromString(psbt);
    final isFinalized = await _wallet.sign(
      psbt: partiallySignedTransaction,
      signOptions: const bdk.SignOptions(
        trustWitnessUtxo: true,
        allowAllSighashes: false,
        removePartialSigs: true,
        tryFinalize: true,
        signWithTapInternalKey: true,
        allowGrinding: false,
      ),
    );
    if (!isFinalized) {
      throw FailedToSignPsbtException('Failed to sign the transaction');
    }

    return partiallySignedTransaction.asString();
  }

  @override
  Future<String> getTxIdFromPsbt(String psbt) async {
    final partiallySignedTransaction =
        await bdk.PartiallySignedTransaction.fromString(
      psbt,
    );
    final tx = partiallySignedTransaction.extractTx();

    return tx.txid();
  }

  @override
  Future<bool> isTxBroadcasted(String txId) async {
    final txs = _wallet.listTransactions(includeRaw: false);

    return txs.any((tx) => tx.txid == txId);
  }

  @override
  Future<String> getTxIdFromTxBytes(List<int> bytes) async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    return tx.txid();
  }

  @override
  Future<String> broadcastTxFromBytes(List<int> bytes) async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    return _blockchain.broadcast(transaction: tx);
  }

  @override
  Future<bool> isAddressUsed(String address) async {
    final txOutputLists = await Future.wait(
      _wallet.listTransactions(includeRaw: false).map((tx) async {
        return await tx.transaction?.output() ?? <bdk.TxOut>[];
      }),
    );

    final outputs = txOutputLists.expand((list) => list).toList();
    final isUsed = await Future.any(
      outputs.map((output) async {
        final generatedAddress = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: output.scriptPubkey.bytes),
          network: _wallet.network(),
        );
        return generatedAddress.asString() == address;
      }),
    ).catchError((_) => false); // To handle empty lists

    return isUsed;
  }

  @override
  Future<String> broadcastPsbt(String psbt) async {
    final partiallySignedTransaction =
        await bdk.PartiallySignedTransaction.fromString(psbt);
    final finalized = await _wallet.sign(
      psbt: partiallySignedTransaction,
      signOptions: const bdk.SignOptions(
        trustWitnessUtxo: true,
        allowAllSighashes: false,
        removePartialSigs: true,
        tryFinalize: true,
        signWithTapInternalKey: true,
        allowGrinding: false,
      ),
    );
    if (!finalized) {
      throw FailedToSignPsbtException('Failed to sign the transaction');
    }

    return _blockchain.broadcast(
      transaction: partiallySignedTransaction.extractTx(),
    );
  }

  @override
  Future<BigInt> getAddressBalanceSat(String address) async {
    final utxos = _wallet.listUnspent();
    BigInt balance = BigInt.zero;

    for (final utxo in utxos) {
      final utxoAddress = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: utxo.txout.scriptPubkey.bytes),
        network: _wallet.network(),
      );

      if (utxoAddress.asString() == address) {
        balance += utxo.txout.value;
      }
    }

    return balance;
  }
}

extension NetworkX on Network {
  bdk.Network get bdkNetwork {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      case Network.liquidMainnet:
      case Network.liquidTestnet:
        throw UnsupportedBdkNetworkException(
          'Liquid network is not supported by BDK',
        );
    }
  }
}

extension BdkNetworkX on bdk.Network {
  Network get network {
    if (this == bdk.Network.bitcoin) {
      return Network.bitcoinMainnet;
    } else {
      return Network.bitcoinTestnet;
    }
  }
}

class FailedToSignPsbtException implements Exception {
  final String message;

  FailedToSignPsbtException(this.message);
}

class UnsupportedBdkNetworkException implements Exception {
  final String message;

  UnsupportedBdkNetworkException(this.message);
}
