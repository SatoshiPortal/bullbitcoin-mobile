import 'dart:typed_data';

import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_wallet_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_repository.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BdkWalletRepositoryImpl
    implements
        WalletRepository,
        BitcoinWalletRepository,
        PayjoinWalletRepository {
  final bdk.Wallet _wallet;

  BdkWalletRepositoryImpl({
    required bdk.Wallet wallet,
  }) : _wallet = wallet;

  static Future<BdkWalletRepositoryImpl> public({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required String dbPath,
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

    return BdkWalletRepositoryImpl(
      wallet: wallet,
    );
  }

  static Future<BdkWalletRepositoryImpl> private({
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required String dbPath,
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

    return BdkWalletRepositoryImpl(
      wallet: wallet,
    );
  }

  @override
  Future<Balance> getBalance() async {
    final balanceInfo = _wallet.getBalance();

    final balance = Balance(
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
  Future<void> sync({required ElectrumServer electrumServer}) async {
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
    await _wallet.sync(blockchain: blockchain);
  }

  @override
  Future<Address> getNewAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<Address> getAddressByIndex(int index) async {
    final addressInfo = _wallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
    );

    return address;
  }

  @override
  Future<Address> getLastUnusedAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final address = Address.bitcoin(
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
  Future<bool> hasTransaction(String txId) async {
    final txs = _wallet.listTransactions(includeRaw: false);

    return txs.any((tx) => tx.txid == txId);
  }

  @override
  Future<String> getTxIdFromTxBytes(List<int> bytes) async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    return tx.txid();
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
