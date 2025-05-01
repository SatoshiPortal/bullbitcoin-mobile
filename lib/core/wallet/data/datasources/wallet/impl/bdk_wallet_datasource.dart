import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
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

class BdkWalletDatasource implements WalletDatasource {
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

  bool get isAnyWalletSyncing => _activeSyncs.isNotEmpty;

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
        debugPrint('Sync completed for wallet: ${wallet.id}');
      } catch (e) {
        debugPrint('Sync error for wallet ${wallet.id}: $e');
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
    final size = psbt.extractTx().size();
    return size.toInt();
  }

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
      debugPrint('Signed PSBT is not finalized');
    } else {
      debugPrint('Signed PSBT is finalized');
    }

    return psbt.asString();
  }

  @override
  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    final bdkWallet = await _createWallet(wallet);
    final unspent = bdkWallet.listUnspent();
    final utxos = await Future.wait(
      unspent.map(
        (unspent) async => WalletUtxoModel.bitcoin(
          txId: unspent.outpoint.txid,
          vout: unspent.outpoint.vout,
          amountSat: unspent.txout.value,
          scriptPubkey: unspent.txout.scriptPubkey.bytes,
          address:
              await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                unspent.txout.scriptPubkey.bytes,
                isTestnet: wallet.isTestnet,
              ),
          isExternalKeyChain:
              unspent.keychain == bdk.KeychainKind.externalChain,
        ),
      ),
    );
    return utxos;
  }

  @override
  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final network = bdkWallet.network();
    final transactions = bdkWallet.listTransactions(includeRaw: true);

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
              final address = await bdk.Address.fromScript(
                script: bdk.ScriptBuf(bytes: output.scriptPubkey.bytes),
                network: network,
              );
              return address.toString() == toAddress;
            }),
          ).catchError((_) => false);

          if (!matches) return null;
        }

        final isIncoming = tx.received > tx.sent;
        final netAmountSat =
            isIncoming
                ? tx.received - tx.sent
                : tx.sent - tx.received - (tx.fee ?? BigInt.zero);
        bool isToSelf =
            true; // Changed to false when an input/output is not from self

        final (inputModels, outputModels) =
            await (
              Future.wait(
                inputs.asMap().entries.map((entry) async {
                  final input = entry.value;
                  final vin = entry.key;
                  final isOwnInput = await isMine(
                    input.scriptSig!.bytes,
                    wallet: wallet as PublicBdkWalletModel,
                  );

                  if (!isOwnInput) {
                    isToSelf = false;
                  }

                  return TransactionInputModel(
                    txId: tx.txid,
                    vin: vin,
                    scriptSig: input.scriptSig!.bytes,
                    previousTxId: input.previousOutput.txid,
                    previousTxVout: input.previousOutput.vout,
                  );
                }).toList(),
              ),
              Future.wait(
                outputs.asMap().entries.map((entry) async {
                  final vout = entry.key;
                  final output = entry.value;
                  final scriptPubkeyBytes = output.scriptPubkey.bytes;
                  final isOwnOutput = await isMine(
                    scriptPubkeyBytes,
                    wallet: wallet as PublicBdkWalletModel,
                  );

                  if (!isOwnOutput) {
                    isToSelf = false;
                  }

                  return TransactionOutputModel.bitcoin(
                    txId: tx.txid,
                    vout: vout,
                    value: output.value,
                    scriptPubkey: scriptPubkeyBytes,
                    address:
                        await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                          scriptPubkeyBytes,
                          isTestnet: wallet.isTestnet,
                        ),
                  );
                }).toList(),
              ),
            ).wait;

        return WalletTransactionModel.bitcoin(
          txId: tx.txid,
          isIncoming: tx.received > tx.sent,
          amountSat: netAmountSat.toInt(),
          feeSat: tx.fee?.toInt() ?? 0,
          confirmationTimestamp: tx.confirmationTime?.timestamp.toInt(),
          isToSelf: isToSelf,
          inputs: inputModels,
          outputs: outputModels,
        );
      }),
    );

    return walletTxs.whereType<WalletTransactionModel>().toList();
  }

  @override
  Future<WalletAddressModel> getNewAddress({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final addressInfo = bdkWallet.getAddress(
      addressIndex: const bdk.AddressIndex.increase(),
    );

    final index = addressInfo.index;
    final address = addressInfo.address.asString();

    return BitcoinWalletAddressModel(index: index, address: address);
  }

  @override
  Future<WalletAddressModel> getLastUnusedAddress({
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
    final address = addressInfo.address.asString();

    return BitcoinWalletAddressModel(index: index, address: address);
  }

  @override
  Future<WalletAddressModel> getAddressByIndex(
    int index, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final addressInfo = bdkWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: index),
    );

    return BitcoinWalletAddressModel(
      index: addressInfo.index,
      address: addressInfo.address.asString(),
    );
  }

  @override
  Future<List<WalletAddressModel>> getReceiveAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final bdkWallet = await _createWallet(wallet);

    final addresses = <BitcoinWalletAddressModel>[];
    for (int i = offset; i < offset + limit; i++) {
      final address = bdkWallet.getAddress(
        addressIndex: bdk.AddressIndex.peek(index: i),
      );

      final model = BitcoinWalletAddressModel(
        index: address.index,
        address: address.address.asString(),
      );
      addresses.add(model);
    }

    return addresses;
  }

  @override
  Future<List<WalletAddressModel>> getChangeAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    final bdkWallet = await _createWallet(wallet);

    final addresses = <BitcoinWalletAddressModel>[];
    for (int i = offset; i < offset + limit; i++) {
      final address = bdkWallet.getInternalAddress(
        addressIndex: bdk.AddressIndex.peek(index: i),
      );

      final model = BitcoinWalletAddressModel(
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
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
    final transactions = bdkWallet.listTransactions(includeRaw: false);

    // TODO: Use future.wait to parallelize the loop and improve performance
    for (final tx in transactions) {
      final txOutputs = tx.transaction?.output();
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
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _createWallet(wallet);
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
