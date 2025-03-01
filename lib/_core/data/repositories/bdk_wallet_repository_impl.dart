import 'dart:typed_data';

import 'package:bb_mobile/_core/data/datasources/pdk_data_source.dart';
import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_wallet_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_repository.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class BdkWalletRepositoryImpl
    implements
        WalletRepository,
        BitcoinWalletRepository,
        PayjoinWalletRepository {
  final String _id;
  final bdk.Wallet _wallet;
  final bdk.Blockchain _blockchain;
  final PdkDataSource? _pdk;

  BdkWalletRepositoryImpl({
    required String id,
    required bdk.Wallet wallet,
    required bdk.Blockchain blockchain,
    PdkDataSource? pdk,
  })  : _id = id,
        _wallet = wallet,
        _blockchain = blockchain,
        _pdk = pdk;

  static Future<BdkWalletRepositoryImpl> public({
    required WalletMetadata walletMetadata,
    required ElectrumServer electrumServer,
  }) async {
    final network = walletMetadata.network.bdkNetwork;

    final external = await bdk.Descriptor.create(
      descriptor: walletMetadata.externalPublicDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: walletMetadata.internalPublicDescriptor,
      network: network,
    );

    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/${walletMetadata.id}';

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbDir),
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

    return BdkWalletRepositoryImpl(
      id: walletMetadata.id,
      wallet: wallet,
      blockchain: blockchain,
    );
  }

  static Future<BdkWalletRepositoryImpl> private({
    required WalletMetadata walletMetadata,
    required ElectrumServer electrumServer,
    required MnemonicSeed mnemonicSeed,
  }) async {
    final network = walletMetadata.network.bdkNetwork;

    final mnemonic =
        await bdk.Mnemonic.fromString(mnemonicSeed.mnemonicWords.join(' '));
    final secretKey = await bdk.DescriptorSecretKey.create(
      network: network,
      mnemonic: mnemonic,
      password: mnemonicSeed.passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (walletMetadata.scriptType) {
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

    // TODO: check if the path of the private wallet can be the same as the public wallet
    //  or if we need to create a new path for the private wallet
    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/${walletMetadata.id}';

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbDir),
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

    return BdkWalletRepositoryImpl(
      id: walletMetadata.id,
      wallet: wallet,
      blockchain: blockchain,
    );
  }

  @override
  String get id => _id;

  @override
  Network get network => _wallet.network().network;

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
  Future<void> sync() async {
    await _wallet.sync(blockchain: _blockchain);
  }

  @override
  Future<Address> getNewAddress() async {
    final addressInfo = _wallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final address = Address.bitcoin(
      address: addressInfo.address.asString(),
      index: addressInfo.index,
      kind: AddressKind.external,
      state: AddressStatus.unused,
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
      kind: AddressKind.external,
      state: await _isAddressUsed(addressInfo.address.asString())
          ? AddressStatus.used
          : AddressStatus.unused,
      balanceSat: await _getAddressBalance(addressInfo.address.asString()),
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
      kind: AddressKind.external,
      state: AddressStatus.unused,
    );

    return address;
  }

  @override
  Future<Payjoin> receivePayjoin() {
    // TODO: implement receivePayjoin
    throw UnimplementedError();
  }

  @override
  Future<Payjoin> sendPayjoin() {
    // TODO: implement sendPayjoin
    throw UnimplementedError();
  }

  @override
  Future<bool> _isMine(Uint8List scriptBytes) async {
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
  Future<String> _buildPsbt({
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
  Future<String> _signPsbt(String psbt) async {
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
  Future<String> _getTxIdFromPsbt(String psbt) async {
    final partiallySignedTransaction =
        await bdk.PartiallySignedTransaction.fromString(
      psbt,
    );
    final tx = partiallySignedTransaction.extractTx();

    return tx.txid();
  }

  @override
  Future<bool> _isTxBroadcasted(String txId) async {
    final txs = _wallet.listTransactions(includeRaw: false);

    return txs.any((tx) => tx.txid == txId);
  }

  @override
  Future<String> _getTxIdFromTxBytes(List<int> bytes) async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    return tx.txid();
  }

  @override
  Future<String> _broadcastTxFromBytes(List<int> bytes) async {
    final tx = await bdk.Transaction.fromBytes(transactionBytes: bytes);

    return _blockchain.broadcast(transaction: tx);
  }

  Future<bool> _isAddressUsed(String address) async {
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

  Future<BigInt> _getAddressBalance(String address) async {
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

  @override
  Future<String> _broadcastPsbt(String psbt) async {
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
