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

class BdkWalletDatasource
    implements AddressDatasource, WalletTransactionDatasource, UtxoDatasource {
  BdkWalletDatasource();
  final Map<String, Completer<void>> _activeSyncs = {};

  void completeActiveSyncForWallet(String walletDb) {
    if (_activeSyncs.containsKey(walletDb)) {
      _activeSyncs[walletDb]?.complete();
      _activeSyncs.remove(walletDb);
    }
  }

  Future<void>? getActiveSyncForWallet(String walletDb) =>
      _activeSyncs[walletDb]?.future;

  Future<BalanceModel> getBalance({
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
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
      final bdkWallet = await _createPublicWallet(wallet);
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
      _activeSyncs[wallet.dbName]?.complete();
    } catch (e) {
      _activeSyncs[wallet.dbName]?.completeError(e);
      rethrow;
    } finally {
      _activeSyncs.remove(wallet.dbName);
    }
  }

  Future<bool> isMine(
    Uint8List scriptBytes, {
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
    final script = bdk.ScriptBuf(bytes: scriptBytes);
    final isMine = bdkWallet.isMine(script: script);

    return isMine;
  }

  Future<String> buildPsbt({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    List<UtxoModel>? unspendable,
    bool? drain,
    List<UtxoModel>? selected,
    bool replaceByFee = true,
    required PublicBdkWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
    bdk.TxBuilder txBuilder;

    // Get the scriptPubkey from the address
    final bdkAddress = await bdk.Address.fromString(
      s: address,
      network: wallet.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
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

    if (selected != null && selected.isNotEmpty) {
      final selectableOutPoints = selected
          .map((input) => bdk.OutPoint(txid: input.txId, vout: input.vout))
          .toList();
      txBuilder.addUtxos(selectableOutPoints);
    }
    if (replaceByFee) txBuilder.enableRbf();

    if (networkFee.isAbsolute) {
      txBuilder = txBuilder.feeAbsolute(BigInt.from(networkFee.value as int));
    } else {
      txBuilder = txBuilder.feeRate(networkFee.value.toDouble());
    }

    // Make sure utxos that are unspendable are not used
    final unspendableOutPoints = unspendable
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
    final bdkWallet = await _createPrivateWallet(wallet);

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

  /* Start UtxoDatasource methods */
  @override
  Future<List<UtxoModel>> getUtxos({
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
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
  /* End UtxoDatasource methods */

  /* Start TransactionDatasource methods */
  @override
  Future<List<WalletTransactionModel>> getTransactions({
    required PublicWalletModel wallet,
    String? toAddress,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);

    var transactions = bdkWallet.listTransactions(includeRaw: true);
    if (toAddress != null && toAddress.isNotEmpty) {
      // Filter transactions by address by returning null for non-matching transactions
      // and then removing null values from the list
      final filtered = await Future.wait(
        transactions.map((tx) async {
          final txOutputs = await tx.transaction?.output();
          if (txOutputs == null) return null;

          final addresses = await Future.wait(
            txOutputs.map(
              (output) => bdk.Address.fromScript(
                script: bdk.ScriptBuf(bytes: output.scriptPubkey.bytes),
                network: bdkWallet.network(),
              ),
            ),
          );

          final matches = addresses.any((address) {
            return address.toString() == toAddress;
          });
          return matches ? tx : null;
        }),
      );
      // Remove null values from the filtered list
      transactions = filtered.whereType<bdk.TransactionDetails>().toList();
    }

    // Map the transactions to WalletTransactionModel
    final List<WalletTransactionModel> walletTxs = await Future.wait(
      transactions.map(
        (tx) async {
          final isIncoming = tx.received > tx.sent;
          final netAmountSat =
              isIncoming ? tx.received - tx.sent : tx.sent - tx.received;

          return WalletTransactionModel.bitcoin(
            txId: tx.txid,
            isIncoming: tx.received > tx.sent,
            amountSat: netAmountSat.toInt(),
            feeSat: tx.fee?.toInt() ?? 0,
            confirmationTimestamp: tx.confirmationTime?.timestamp.toInt(),
          );
        },
      ),
    );

    return walletTxs;
  }
  /* End TransactionDatasource methods */

  /* Start AddressDatasource methods */
  @override
  Future<AddressModel> getNewAddress({
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
    final addressInfo = bdkWallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final index = addressInfo.index;
    final address = addressInfo.address.asString();

    return BitcoinAddressModel(index: index, address: address);
  }

  @override
  Future<AddressModel> getLastUnusedAddress({
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
    final addressInfo = bdkWallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final index = addressInfo.index;
    final address = addressInfo.address.asString();

    return BitcoinAddressModel(index: index, address: address);
  }

  @override
  Future<AddressModel> getAddressByIndex(
    int index, {
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
    final addressInfo = bdkWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    return BitcoinAddressModel(
      index: addressInfo.index,
      address: addressInfo.address.asString(),
    );
  }

  @override
  Future<List<AddressModel>> getReceiveAddresses({
    required PublicWalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);

    final addresses = <BitcoinAddressModel>[];
    for (int i = offset; i < offset + limit; i++) {
      final address = bdkWallet.getAddress(
        addressIndex: bdk.AddressIndex.peek(index: i),
      );

      final model = BitcoinAddressModel(
        index: address.index,
        address: address.address.asString(),
      );
      addresses.add(model);
    }

    return addresses;
  }

  @override
  Future<List<AddressModel>> getChangeAddresses({
    required PublicWalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);

    final addresses = <BitcoinAddressModel>[];
    for (int i = offset; i < offset + limit; i++) {
      final address = bdkWallet.getInternalAddress(
        addressIndex: bdk.AddressIndex.peek(index: i),
      );

      final model = BitcoinAddressModel(
        index: address.index,
        address: address.address.asString(),
      );

      addresses.add(model);
    }

    return addresses;
  }

  @override
  Future<bool> isAddressUsed(
    String address, {
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
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

  @override
  Future<BigInt> getAddressBalanceSat(
    String address, {
    required PublicWalletModel wallet,
  }) async {
    final bdkWallet = await _createPublicWallet(wallet);
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
  /* End AddressDatasource methods */

  Future<bdk.Wallet> _createPublicWallet(PublicWalletModel walletModel) async {
    if (walletModel is! PublicBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PublicBdkWalletModel');
    }

    final network =
        walletModel.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: walletModel.externalDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: walletModel.internalDescriptor,
      network: network,
    );

    // Create the database configuration
    final dbPath = await _getDbPath(walletModel.dbName);
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

  Future<bdk.Wallet> _createPrivateWallet(
    PrivateWalletModel walletModel,
  ) async {
    if (walletModel is! PrivateBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PrivateBdkWalletModel');
    }

    final network =
        walletModel.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final bdkMnemonic = await bdk.Mnemonic.fromString(walletModel.mnemonic);
    final secretKey = await bdk.DescriptorSecretKey.create(
      network: network,
      mnemonic: bdkMnemonic,
      password: walletModel.passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (walletModel.scriptType) {
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
    final dbPath = await _getDbPath(walletModel.dbName);
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
