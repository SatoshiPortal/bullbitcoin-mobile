import 'dart:async';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter/material.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkWalletDatasource {
  @visibleForTesting
  final Map<String, int> syncExecutions = {};
  final Map<String, Future<void>> _activeSyncs;
  final StreamController<String> _walletSyncStartedController;
  final StreamController<String> _walletSyncFinishedController;

  LwkWalletDatasource()
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
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      final balances = await lwkWallet.balances();

      final lBtcAssetBalance =
          balances.firstWhere((balance) {
            final assetId = _lBtcAssetId(
              wallet.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
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
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<void> sync({
    required WalletModel wallet,
    required ElectrumServerModel electrumServer,
  }) {
    // TODO: if needed, add these debugPrint to a filterable logger.debug
    // TODO: to avoid spamming the terminal with recurring prints
    //debugPrint('[Sync] Sync requested for wallet: ${wallet.id}');
    return _activeSyncs.putIfAbsent(wallet.id, () async {
      try {
        //debugPrint('[Sync] New sync started for wallet: ${wallet.id}');
        _walletSyncStartedController.add(wallet.id);
        syncExecutions.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);
        final lwkWallet = await _createPublicWallet(wallet);
        await lwkWallet.sync_(
          electrumUrl: electrumServer.url,
          validateDomain: electrumServer.validateDomain,
        );
        //debugPrint('[Sync] Sync completed for wallet: ${wallet.id}');
      } catch (e) {
        if (e is lwk.LwkError) {
          throw e.msg;
        } else {
          rethrow;
        }
      } finally {
        _walletSyncFinishedController.add(wallet.id);
        // Remove the sync so future syncs can be triggered
        // Do not await this, as it is not necessary and can cause deadlocks
        // since it returns the Future from the map.
        // ignore: unawaited_futures
        _activeSyncs.remove(wallet.id);
      }
    });
  }

  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      final utxos = await lwkWallet.utxos();

      final unspent = utxos.map((utxo) {
        return WalletUtxoModel.liquid(
          txId: utxo.outpoint.txid,
          vout: utxo.outpoint.vout,
          amountSat: utxo.unblinded.value,
          scriptPubkey: utxo.scriptPubkey,
          standardAddress: utxo.address.standard,
          confidentialAddress: utxo.address.confidential,
        );
      });

      return unspent.toList();
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<({String standard, String confidential, int index})> getNewAddress({
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      // For LWK, address reuse is taken care of by the repository and the address history database,
      //  so here we just get the last unused address.
      final lastUnusedAddressInfo = await lwkWallet.addressLastUnused();
      final address = (
        index: lastUnusedAddressInfo.index!,
        standard: lastUnusedAddressInfo.standard,
        confidential: lastUnusedAddressInfo.confidential,
      );
      return address;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<int> getLastUnusedAddressIndex({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      if (isChange) {
        throw Exception(
          'Change addresses are not retrievable with LWK at the moment.',
        );
      }
      final addressInfo = await lwkWallet.addressLastUnused();
      return addressInfo.index!;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<({String standard, String confidential, int index})> getAddressByIndex(
    int index, {
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      final addressInfo = await lwkWallet.address(index: index);
      final address = (
        index: addressInfo.index!,
        standard: addressInfo.standard,
        confidential: addressInfo.confidential,
      );
      return address;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<List<({String standard, String confidential, int index})>>
  getReceiveAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      final addresses = <({String standard, String confidential, int index})>[];
      for (int i = offset; i < offset + limit; i++) {
        final addressInfo = await lwkWallet.address(index: i);
        final address = (
          index: addressInfo.index!,
          standard: addressInfo.standard,
          confidential: addressInfo.confidential,
        );
        addresses.add(address);
      }
      return addresses;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<List<({String standard, String confidential, int index})>>
  getChangeAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  }) async {
    try {
      return [];
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  }) async {
    try {
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
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<BigInt> getAddressBalanceSat(
    String address, {
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      final utxos = await lwkWallet.utxos();
      BigInt balance = BigInt.zero;
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
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  String _lBtcAssetId(Network network) {
    return network == Network.liquidTestnet
        ? lwk.lTestAssetId
        : lwk.lBtcAssetId;
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      final transactions = await lwkWallet.txs();
      final usedAddressesMap = await _getUsedAddressesMap(wallet: wallet);
      final network =
          wallet.isTestnet ? Network.liquidTestnet : Network.liquidMainnet;
      final lbtcAssetId = _lBtcAssetId(network);
      final walletTxs = await Future.wait(
        transactions.map((tx) async {
          if (toAddress != null && toAddress.isNotEmpty) {
            final matches = tx.outputs.any(
              (output) =>
                  output.address.standard == toAddress ||
                  output.address.confidential == toAddress,
            );
            if (!matches) return null;
          }
          final isIncoming = tx.kind == 'incoming';
          final balances = tx.balances;
          final finalBalance =
              balances
                  .where((e) => e.assetId == lbtcAssetId)
                  .map((e) => e.value)
                  .firstOrNull ??
              0;
          final isToSelf =
              tx.kind == 'redeposit' || finalBalance.abs() == tx.fee.toInt();
          int changeAmountInToSelf = 0;
          final (inputs, outputs) =
              await (
                Future.wait(
                  tx.inputs.asMap().entries.map((entry) async {
                    final vin = entry.key;
                    final input = entry.value;
                    final walletInputAddress =
                        usedAddressesMap[input.address.standard] ??
                        usedAddressesMap[input.address.confidential];
                    final isOwn = isToSelf || walletInputAddress != null;
                    return TransactionInputModel.liquid(
                      txId: tx.txid,
                      vin: vin,
                      isOwn: isOwn,
                      value: input.unblinded.value,
                      scriptPubkey: input.scriptPubkey,
                      previousTxId: input.outpoint.txid,
                      previousTxVout: input.outpoint.vout,
                    );
                  }),
                ),
                Future.wait(
                  tx.outputs.asMap().entries.map((entry) async {
                    final vout = entry.key;
                    final output = entry.value;
                    final walletOutputAddress =
                        usedAddressesMap[output.address.standard] ??
                        usedAddressesMap[output.address.confidential];
                    final isOwn = isToSelf || walletOutputAddress != null;
                    if (isToSelf && walletOutputAddress == null) {
                      changeAmountInToSelf += output.unblinded.value.toInt();
                    }
                    return TransactionOutputModel.liquid(
                      txId: tx.txid,
                      vout: vout,
                      isOwn: isOwn,
                      value: output.unblinded.value,
                      scriptPubkey: output.scriptPubkey,
                      address: output.address.confidential,
                    );
                  }),
                ),
              ).wait;
          final sumOutputs = outputs
              .map((i) => i.value?.toInt() ?? 0)
              .fold(0, (int a, b) => a + b);
          final netAmountSat =
              isToSelf
                  ? sumOutputs - changeAmountInToSelf
                  : isIncoming
                  ? finalBalance
                  : finalBalance.abs() - tx.fee.toInt();
          return WalletTransactionModel(
            txId: tx.txid,
            isIncoming: isIncoming,
            amountSat: netAmountSat,
            feeSat: tx.fee.toInt(),
            confirmationTimestamp: tx.timestamp,
            isToSelf: isToSelf,
            inputs: inputs,
            outputs: outputs,
            isLiquid: true,
            isTestnet: wallet.isTestnet,
            unblindedUrl: tx.unblindedUrl,
          );
        }),
      );
      return walletTxs.whereType<WalletTransactionModel>().toList();
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<String> buildPset({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await _createPublicWallet(wallet);
      if (networkFee.isAbsolute) {
        throw Exception('Absolute fee is not supported for liquid yet!');
      }
      log.info(networkFee.value.toDouble().toString());
      final pset = await lwkWallet.buildLbtcTx(
        sats: BigInt.from(amountSat ?? 0),
        outAddress: address,
        feeRate: networkFee.value.toDouble() * 1000,
        drain: drain,
      );
      final decoded = await lwkWallet.decodeTx(pset: pset);
      log.info(decoded.absoluteFees.toString());
      return pset;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<String> signPset(
    String pset, {
    required PrivateLwkWalletModel wallet,
  }) async {
    try {
      final lwkWallet = await _createPrivateWallet(wallet);
      final signedPset = await lwkWallet.signTx(
        network: wallet.isTestnet ? lwk.Network.testnet : lwk.Network.mainnet,
        pset: pset,
        mnemonic: wallet.mnemonic,
      );
      return signedPset;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<(int, int)> decodeAbsoluteFeesFromPset(String pset) async {
    try {
      final decoded = await lwk.getSizeAndAbsoluteFees(pset: pset);
      debugPrint(decoded.absoluteFees.toString());
      // final decoded = await lwkWallet.decodeTx(pset: pset);
      return (
        decoded.discountedVsize.toInt(),
        decoded.absoluteFees.first.value,
      );
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<Map<String, ({String standard, String confidential, int index})>>
  _getUsedAddressesMap({
    required WalletModel wallet,
    int batchSize = 10,
  }) async {
    try {
      final lastIndex = await getLastUnusedAddressIndex(wallet: wallet);
      final addressMap =
          <String, ({String standard, String confidential, int index})>{};
      final List<Future<void>> currentBatch = [];
      for (int i = 0; i <= lastIndex; i++) {
        final future = getAddressByIndex(i, wallet: wallet).then((addr) {
          final address = addr;
          addressMap[address.standard] = address;
          addressMap[address.confidential] = address;
        });
        currentBatch.add(future);
        if (currentBatch.length >= batchSize) {
          await Future.wait(currentBatch);
          currentBatch.clear();
        }
      }
      if (currentBatch.isNotEmpty) {
        await Future.wait(currentBatch);
      }
      return addressMap;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<String> _getDbPath(String dbName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$dbName';
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<lwk.Wallet> _createPublicWallet(WalletModel walletModel) async {
    try {
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
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<lwk.Wallet> _createPrivateWallet(WalletModel walletModel) async {
    try {
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
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
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
