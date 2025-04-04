import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bdk_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/tx_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

class BdkWalletDatasource {
  const BdkWalletDatasource();

  Future<BalanceModel> getBalance({
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final balanceInfo = bdkWallet.getBalance();

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

  Future<void> sync({
    required PublicBdkWalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
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
    await bdkWallet.sync(blockchain: blockchain);
  }

  Future<(int, String)> getNewAddress({
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final addressInfo = bdkWallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final index = addressInfo.index;
    final address = addressInfo.address.asString();

    return (index, address);
  }

  Future<String> getAddressByIndex(
    int index, {
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final addressInfo = bdkWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    return addressInfo.address.asString();
  }

  Future<(int, String)> getLastUnusedAddress({
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final addressInfo = bdkWallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final index = addressInfo.index;
    final address = addressInfo.address.asString();

    return (index, address);
  }

  Future<bool> isMine(
    Uint8List scriptBytes, {
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final script = bdk.ScriptBuf(bytes: scriptBytes);
    final isMine = bdkWallet.isMine(script: script);

    return isMine;
  }

  Future<List<UtxoModel>> listUnspent({
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final unspent = bdkWallet.listUnspent();
    final utxos = unspent
        .map(
          (unspent) => UtxoModel(
            scriptPubkey: unspent.txout.scriptPubkey.bytes,
            txId: unspent.outpoint.txid,
            vout: unspent.outpoint.vout,
            value: unspent.txout.value,
          ),
        )
        .toList();
    return utxos;
  }

  Future<String> buildPsbt({
    required String address,
    required bool isTestnet,
    required NetworkFee networkFee,
    int? amountSat,
    List<TxInputModel>? unspendableInputs,
    bool? drain,
    List<TxInputModel>? selectedInputs,
    bool replaceByFees = true,
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    bdk.TxBuilder txBuilder;

    // Get the scriptPubkey from the address
    final bdkAddress = await bdk.Address.fromString(
      s: address,
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    final script = bdkAddress.scriptPubkey();

    // Check if the transaction is a drain transaction
    if (drain == true) {
      txBuilder = bdk.TxBuilder().drainWallet().drainTo(script);
    } else {
      if (amountSat == null) {
        throw ArgumentError('amountSat is required');
      }
      txBuilder = bdk.TxBuilder().addRecipient(script, BigInt.from(amountSat));
    }

    if (selectedInputs != null && selectedInputs.isNotEmpty) {
      final selectableOutPoints = selectedInputs
          .map((input) => bdk.OutPoint(txid: input.txId, vout: input.vout))
          .toList();
      txBuilder.addUtxos(selectableOutPoints);
    }
    if (replaceByFees) txBuilder.enableRbf();

    if (networkFee.isAbsolute) {
      txBuilder = txBuilder.feeAbsolute(BigInt.from(networkFee.value as int));
    } else {
      txBuilder = txBuilder.feeRate(networkFee.value.toDouble());
    }

    // Make sure utxos that are unspendable are not used
    final unspendableOutPoints = unspendableInputs
        ?.map((input) => bdk.OutPoint(txid: input.txId, vout: input.vout))
        .toList();

    // TODO: MOVE THIS TO THE TRANSACTION REPOSITORY, the repository should check the unspendable and spendable inputs
    // and build the transaction accordingly or return an error
    if (unspendableOutPoints != null && unspendableOutPoints.isNotEmpty) {
      // Check if there are unspents that are not in unspendableOutpoints so a transaction can be built
      final unspents = bdkWallet.listUnspent();
      final unspendableOutPointsSet = unspendableOutPoints.toSet();
      final unspendableUtxos = unspents.where((utxo) {
        return unspendableOutPointsSet.contains(utxo.outpoint);
      }).toList();

      if (unspendableUtxos.length == unspents.length) {
        throw NoSpendableUtxoException(
          'All unspents are unspendable',
        );
      }

      txBuilder = txBuilder.unSpendable(unspendableOutPoints);
    }

    // Finish the transaction building process
    final (psbt, _) = await txBuilder.finish(bdkWallet);

    return psbt.asString();
  }

  Future<String> signPsbt(
    String unsignedPsbt, {
    required PrivateBdkWalletModel wallet,
  }) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(unsignedPsbt);
    final bdkWallet = await _createPrivateWallet(
      scriptType: wallet.scriptType,
      mnemonic: wallet.mnemonic,
      passphrase: wallet.passphrase,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );

    final isFinalized = await bdkWallet.sign(
      psbt: psbt,
      signOptions: const bdk.SignOptions(
        trustWitnessUtxo: true,
        allowAllSighashes: false,
        removePartialSigs: true,
        tryFinalize: true,
        signWithTapInternalKey: false,
        allowGrinding: true,
      ),
    );
    if (!isFinalized) {
      debugPrint('Signed PSBT is not finalized');
    } else {
      debugPrint('Signed PSBT is finalized');
    }

    return psbt.asString();
  }

  Future<bool> isAddressUsed(
    String address, {
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final transactions = bdkWallet.listTransactions(includeRaw: false);

    // TODO: Use future.wait to parallelize the loop and improve performance
    for (final tx in transactions) {
      final txOutputs = await tx.transaction?.output();
      if (txOutputs != null) {
        for (final output in txOutputs) {
          final generatedAddress = await bdk.Address.fromScript(
            script: bdk.ScriptBuf(bytes: output.scriptPubkey.bytes),
            network: bdkWallet.network(),
          );

          if (generatedAddress.asString() == address) {
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<BigInt> getAddressBalanceSat(
    String address, {
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final utxos = bdkWallet.listUnspent();
    BigInt balance = BigInt.zero;

    for (final utxo in utxos) {
      final utxoAddress = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: utxo.txout.scriptPubkey.bytes),
        network: bdkWallet.network(),
      );

      if (utxoAddress.asString() == address) {
        balance += utxo.txout.value;
      }
    }

    return balance;
  }

  Future<List<WalletTransactionModel>> getTransactions(
    String walletId, {
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(
      externalDescriptor: wallet.externalDescriptor,
      internalDescriptor: wallet.internalDescriptor,
      isTestnet: wallet.isTestnet,
      dbName: wallet.dbName,
    );
    final transactions = bdkWallet.listTransactions(includeRaw: false);
    final List<WalletTransactionModel> walletTxs = transactions
        .map(
          (tx) => WalletTransactionModel(
            network: bdkWallet.network().network,
            txId: tx.txid,
            isIncoming:
                tx.sent == BigInt.from(0) && tx.received > BigInt.from(0),
            amount: tx.sent.toInt(),
            fees: tx.fee?.toInt() ?? 0,
            confirmationTimestamp: tx.confirmationTime?.timestamp.toInt(),
          ),
        )
        .toList();

    return walletTxs;
  }

  Future<bdk.Wallet> _createPublicWallet({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required String dbName,
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

    // Create the database configuration
    final dbPath = await _getDbPath(dbName);
    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return wallet;
  }

  Future<bdk.Wallet> _createPrivateWallet({
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required String dbName,
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

    // Create the database configuration
    final dbPath = await _getDbPath(dbName);
    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return wallet;
  }

  Future<String> _getDbPath(String dbName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$dbName';
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

class NoSpendableUtxoException implements Exception {
  final String message;

  NoSpendableUtxoException(this.message);
}
