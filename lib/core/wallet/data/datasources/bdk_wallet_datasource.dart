import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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
  @visibleForTesting
  final Map<String, int> syncExecutions = {};
  final Map<String, Future<void>> _activeSyncs;
  final StreamController<String> _walletSyncStartedController;
  final StreamController<String> _walletSyncFinishedController;

  BdkWalletDatasource()
    : _activeSyncs = {},
      _walletSyncStartedController = StreamController<String>.broadcast(),
      _walletSyncFinishedController = StreamController<String>.broadcast();

  Stream<String> get walletSyncStartedStream =>
      _walletSyncStartedController.stream;

  Stream<String> get walletSyncFinishedStream =>
      _walletSyncFinishedController.stream;

  bool isWalletSyncing({String? walletId}) =>
      walletId == null
          ? _activeSyncs.isNotEmpty
          : _activeSyncs.containsKey(walletId);

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    final bdkWallet = await _createWallet(wallet);
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
    required WalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) {
    // putIfAbsent ensures only one sync starts for each wallet ID,
    //  all others await the same Future.
    // TODO: if needed, add these debugPrint to a filterable logger.debug
    // TODO: to avoid spamming the terminal with recurring prints
    // debugPrint('Sync requested for wallet: ${wallet.id}');
    return _activeSyncs.putIfAbsent(wallet.id, () async {
      try {
        // debugPrint('New sync started for wallet: ${wallet.id}');
        // Notify that the wallet is syncing through a stream for other
        // parts of the app to listen to so they can show a syncing indicator
        _walletSyncStartedController.add(wallet.id);

        // Increment the sync execution count for this wallet for testing purposes
        syncExecutions.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);
        final bdkWallet = await _createWallet(wallet);

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
        // debugPrint('Sync completed for wallet: ${wallet.id}');
      } catch (e) {
        // debugPrint('Sync error for wallet ${wallet.id}: $e');
        rethrow;
      } finally {
        // Notify that the wallet has been synced through a stream for other
        // parts of the app to listen to
        _walletSyncFinishedController.add(wallet.id);
        // Remove the sync so future syncs can be triggered
        // Do not await this, as it is not necessary and can cause deadlocks
        // since it returns the Future from the map.
        // ignore: unawaited_futures
        _activeSyncs.remove(wallet.id);
      }
    });
  }

  Future<bool> isMine(
    Uint8List scriptBytes, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final script = bdk.ScriptBuf(bytes: scriptBytes);
    final isMine = bdkWallet.isMine(script: script);

    return isMine;
  }

  Future<String> buildPsbt({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    List<({String txId, int vout})>? unspendable,
    bool? drain,
    List<WalletUtxoModel>? selected,
    bool replaceByFee = true,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
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
      final selectableOutPoints =
          selected
              .map((utxo) => bdk.OutPoint(txid: utxo.txId, vout: utxo.vout))
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
    final unspendableOutPoints =
        unspendable
            ?.map((input) => bdk.OutPoint(txid: input.txId, vout: input.vout))
            .toList();

    // TODO: MOVE THIS TO THE TRANSACTION REPOSITORY, the repository should check the unspendable and spendable inputs
    // and build the transaction accordingly or return an error
    if (unspendableOutPoints != null && unspendableOutPoints.isNotEmpty) {
      // Check if there are unspents that are not in unspendableOutpoints so a transaction can be built
      final unspents = bdkWallet.listUnspent();
      final unspendableOutPointsSet = unspendableOutPoints.toSet();
      final unspendableUtxos =
          unspents.where((utxo) {
            return unspendableOutPointsSet.contains(utxo.outpoint);
          }).toList();

      if (unspendableUtxos.length == unspents.length) {
        throw NoSpendableUtxoException('All unspents are unspendable');
      }

      txBuilder = txBuilder.unSpendable(unspendableOutPoints);
    }

    // Finish the transaction building process
    final (psbt, _) = await txBuilder.finish(bdkWallet);

    return psbt.asString();
  }

  Future<int> decodeTxSize(String psbtString) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(psbtString);
    final size = psbt.extractTx().vsize();
    return size.toInt();
  }

  Future<int> getFeeAmount(String psbtString) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(psbtString);
    final fee = psbt.feeAmount() ?? BigInt.zero;
    return fee.toInt();
  }
  // 25000 - 988

  Future<String> signPsbt(
    String unsignedPsbt, {
    required PrivateBdkWalletModel wallet,
  }) async {
    final psbt = await bdk.PartiallySignedTransaction.fromString(unsignedPsbt);
    final bdkWallet = await _createPrivateWallet(wallet);

    final isFinalized = bdkWallet.sign(
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
      log.info('Signed PSBT is not finalized');
    } else {
      log.info('Signed PSBT is finalized');
    }

    return psbt.asString();
  }

  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    final bdkWallet = await _createWallet(wallet);
    final unspent = bdkWallet.listUnspent();
    final utxos = await Future.wait(
      unspent.map((unspent) async {
        final address =
            await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
              unspent.txout.scriptPubkey.bytes,
              isTestnet: wallet.isTestnet,
            );
        return WalletUtxoModel.bitcoin(
          txId: unspent.outpoint.txid,
          vout: unspent.outpoint.vout,
          amountSat: unspent.txout.value,
          scriptPubkey: unspent.txout.scriptPubkey.bytes,
          // Since it's a BDK utxo, the address should not be null
          // but we return an empty string in case it is for some reason
          address: address ?? '',
          isExternalKeyChain:
              unspent.keychain == bdk.KeychainKind.externalChain,
        );
      }),
    );
    return utxos;
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final transactions = bdkWallet.listTransactions(includeRaw: true);
    final allTransactionOutputs = await _getAllOutputsOfTransactions(
      transactions,
      wallet: wallet,
    );

    // Map the transactions to WalletTransactionModel
    final List<WalletTransactionModel?> walletTxs = await Future.wait(
      transactions.map((tx) async {
        final (inputs, outputs) = (
          tx.transaction!.input(),
          tx.transaction!.output(),
        );

        if (toAddress != null && toAddress.isNotEmpty) {
          // Filter transactions by address by returning null for non-matching transactions
          // and then removing null values from the list with whereType at the end of the method
          final matches = await Future.any(
            outputs.map((output) async {
              final address =
                  await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                    output.scriptPubkey.bytes,
                    isTestnet: wallet.isTestnet,
                  );
              if (address == null) return false;
              return address == toAddress;
            }),
          ).catchError((_) => false);

          if (!matches) return null;
        }

        // Map inputs and outputs to their respective models
        final inputModels =
            inputs.asMap().entries.map((entry) {
              final input = entry.value;
              final vin = entry.key;
              final previousOutput = input.previousOutput;
              final output = allTransactionOutputs.firstWhereOrNull(
                (output) =>
                    output.txId == previousOutput.txid &&
                    output.vout == previousOutput.vout,
              );

              return TransactionInputModel.bitcoin(
                txId: tx.txid,
                vin: vin,
                isOwn: output?.isOwn ?? false,
                scriptSig: input.scriptSig?.bytes,
                previousTxId: previousOutput.txid,
                previousTxVout: previousOutput.vout,
              );
            }).toList();
        final outputModels =
            allTransactionOutputs
                .where((output) => output.txId == tx.txid)
                .toList();

        // Check if all inputs and outputs are owned by the wallet itself
        final isToSelf =
            inputModels.every((input) => input.isOwn) &&
            outputModels.every((output) => output.isOwn);

        final isIncoming = tx.received > tx.sent;
        final netAmountSat =
            isToSelf
                ? // When sending to self, the fee is paid by this wallet and is
                // the only thing that changes from the balance
                tx.sent - (tx.fee ?? BigInt.zero)
                : isIncoming
                ? // If incoming, fee is paid by sender, so not deducted from
                // wallet's balance
                tx.received - tx.sent
                : // If outgoing, fee is paid by this wallet, so deducted here
                // to know the net amount
                tx.sent - tx.received - (tx.fee ?? BigInt.zero);

        return WalletTransactionModel(
          txId: tx.txid,
          isIncoming: tx.received > tx.sent,
          amountSat: netAmountSat.toInt(),
          feeSat: tx.fee?.toInt() ?? 0,
          confirmationTimestamp: tx.confirmationTime?.timestamp.toInt(),
          isToSelf: isToSelf,
          inputs: inputModels,
          outputs: outputModels,
          isLiquid: false,
          isTestnet: wallet.isTestnet,
        );
      }),
    );

    return walletTxs.whereType<WalletTransactionModel>().toList();
  }

  Future<({String address, int index})> getNewAddress({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    // Get the last unused address instead of increasing the address right away
    //  so we start at index 0.
    final addressInfo = bdkWallet.getAddress(
      addressIndex: const bdk.AddressIndex.lastUnused(),
    );

    final index = addressInfo.index;
    final address = addressInfo.address.asString();

    // Now increase the address index so the next call to getAddress
    //  will return a new address with the next index.
    bdkWallet.getAddress(addressIndex: const bdk.AddressIndex.increase());

    return (index: index, address: address);
  }

  Future<int> getLastUnusedAddressIndex({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    const lastUnusedAddressIndex = bdk.AddressIndex.lastUnused();

    final addressInfo =
        isChange
            ? bdkWallet.getInternalAddress(addressIndex: lastUnusedAddressIndex)
            : bdkWallet.getAddress(addressIndex: lastUnusedAddressIndex);

    final index = addressInfo.index;

    return index;
  }

  Future<String> getAddressByIndex(
    int index, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final addressInfo = bdkWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    final address = addressInfo.address.asString();

    return address;
  }

  Future<List<({String address, int index})>> getReceiveAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final bdkWallet = await _createWallet(wallet);

    final addresses = <({String address, int index})>[];
    for (int i = offset; i < offset + limit; i++) {
      final addressInfo = bdkWallet.getAddress(
        addressIndex: bdk.AddressIndex.peek(index: i),
      );

      final address = (
        index: addressInfo.index,
        address: addressInfo.address.asString(),
      );
      addresses.add(address);
    }

    return addresses;
  }

  Future<List<({String address, int index})>> getChangeAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final bdkWallet = await _createWallet(wallet);

    final addresses = <({String address, int index})>[];
    for (int i = offset; i < offset + limit; i++) {
      final addressInfo = bdkWallet.getInternalAddress(
        addressIndex: bdk.AddressIndex.peek(index: i),
      );

      final address = (
        index: addressInfo.index,
        address: addressInfo.address.asString(),
      );
      addresses.add(address);
    }

    return addresses;
  }

  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final transactions = bdkWallet.listTransactions(includeRaw: false);

    // TODO: Use future.wait to parallelize the loop and improve performance
    for (final tx in transactions) {
      final txOutputs = tx.transaction?.output();
      if (txOutputs != null) {
        for (final output in txOutputs) {
          final generatedAddress =
              await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                output.scriptPubkey.bytes,
                isTestnet: wallet.isTestnet,
              );
          if (generatedAddress == null) continue;
          if (generatedAddress == address) {
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<BigInt> getAddressBalanceSat(
    String address, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final utxos = bdkWallet.listUnspent();
    BigInt balance = BigInt.zero;

    for (final utxo in utxos) {
      final utxoAddress =
          await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            utxo.txout.scriptPubkey.bytes,
            isTestnet: wallet.isTestnet,
          );
      if (utxoAddress == null) continue;

      if (utxoAddress == address) {
        balance += utxo.txout.value;
      }
    }

    return balance;
  }

  Future<List<BitcoinTransactionOutputModel>> _getAllOutputsOfTransactions(
    List<bdk.TransactionDetails> transactions, {
    required WalletModel wallet,
  }) async {
    final listOfOutputs = await Future.wait(
      transactions.map((tx) async {
        final outputs = tx.transaction!.output();
        final models = await Future.wait(
          outputs.asMap().entries.map((outputEntry) async {
            final vout = outputEntry.key;
            final output = outputEntry.value;
            final scriptPubkeyBytes = output.scriptPubkey.bytes;
            final address =
                await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                  output.scriptPubkey.bytes,
                  isTestnet: wallet.isTestnet,
                );

            return TransactionOutputModel.bitcoin(
              txId: tx.txid,
              vout: vout,
              isOwn: await isMine(scriptPubkeyBytes, wallet: wallet),
              value: output.value,
              scriptPubkey: scriptPubkeyBytes,
              address: address,
            );
          }),
        );
        return models;
      }),
    );

    final allOutputs = listOfOutputs.expand((i) => i).toList();
    return allOutputs.whereType<BitcoinTransactionOutputModel>().toList();
  }

  Future<bdk.Wallet> _createWallet(WalletModel walletModel) {
    if (walletModel is PublicBdkWalletModel) {
      return _createPublicWallet(walletModel);
    } else if (walletModel is PrivateBdkWalletModel) {
      return _createPrivateWallet(walletModel);
    } else {
      throw ArgumentError('Unsupported wallet model type');
    }
  }

  Future<bdk.Wallet> _createPublicWallet(WalletModel walletModel) async {
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

  Future<bdk.Wallet> _createPrivateWallet(WalletModel walletModel) async {
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
