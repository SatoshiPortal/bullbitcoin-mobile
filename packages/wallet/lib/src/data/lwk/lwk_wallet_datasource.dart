import 'lwk_wallet_transaction_mapper.dart';
import 'lwk_facade.dart';
import 'lwk_electrum_source.dart';
import 'dart:async';

import 'package:primitives/primitives.dart' show BullException;
import 'package:primitives/primitives.dart'
    show RelativeFee, RelativeFeeDisplay;
import 'package:bull_logger/bull_logger.dart';
import 'package:wallet/wallet.dart';
import 'package:flutter/material.dart';
import 'package:bull_sdk/lwk.dart' as lwk;

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

  bool isWalletSyncing({String? walletId}) => walletId == null
      ? _activeSyncs.isNotEmpty
      : _activeSyncs.containsKey(walletId);

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final balances = await lwkWallet.balances();

      final lBtcAssetBalance = balances.firstWhere((balance) {
        final assetId = _lBtcAssetId(
          wallet.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
        );
        return balance.assetId == assetId;
      }).value;

      final balance = BalanceModel(
        confirmedSat: lBtcAssetBalance,
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: lBtcAssetBalance,
        totalSat: lBtcAssetBalance,
      );

      return balance;
    } catch (e) {
      if (e is lwk.LwkError) {
        if (e.toString().contains('UpdateOnDifferentStatus') ||
            e.msg.contains('UpdateOnDifferentStatus')) {
          await delete(wallet: wallet);
        }
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<void> sync({
    required WalletModel wallet,
    required WalletConnectionPort electrumServer,
  }) {
    // TODO: if needed, add these debugPrint to a filterable logger.debug
    // TODO: to avoid spamming the terminal with recurring prints
    //debugPrint('[Sync] Sync requested for wallet: ${wallet.id}');
    return _activeSyncs.putIfAbsent(wallet.id, () async {
      try {
        //debugPrint('[Sync] New sync started for wallet: ${wallet.id}');
        _walletSyncStartedController.add(wallet.id);
        syncExecutions.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);
        final lwkWallet = await LwkFacade.createPublicWallet(wallet);
        await synchronizeLwkElectrum(
          wallet: lwkWallet,
          electrumUrl: electrumServer.url,
          validateDomain: electrumServer.validateDomain,
          timeout: electrumServer.effectiveTimeout,
        );
        //debugPrint('[Sync] Sync completed for wallet: ${wallet.id}');
      } catch (e) {
        if (e is lwk.LwkError) {
          if (e.msg.contains('UpdateOnDifferentStatus')) {
            await delete(wallet: wallet);
          }
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
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
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

  Future<({String standard, String confidential, int index})>
  getLastUnusedAddress({required WalletModel wallet}) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
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
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
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
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
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

  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
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

  Future<Map<String, BigInt>> getAddressBalancesSat({
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final utxos = await lwkWallet.utxos();
      final addressBalances = <String, BigInt>{};

      for (final utxo in utxos) {
        final assetId = _lBtcAssetId(
          Network.fromEnvironment(isTestnet: wallet.isTestnet, isLiquid: true),
        );
        if (utxo.unblinded.asset != assetId) {
          continue;
        }

        addressBalances[utxo.address.confidential] =
            (addressBalances[utxo.address.confidential] ?? BigInt.zero) +
            utxo.unblinded.value;
      }
      return addressBalances;
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
        ? lwk.getLtestAssetId()
        : lwk.getLbtcAssetId();
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? txId,
    String? toAddress,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final transactions = (await lwkWallet.txs()).where(
        (tx) => txId == null || tx.txid == txId,
      );
      final usedAddressesMap = await _getUsedAddressesMap(wallet: wallet);
      final network = wallet.isTestnet
          ? Network.liquidTestnet
          : Network.liquidMainnet;
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
          return mapLwkTransactionDetails(
            tx,
            lbtcAssetId: lbtcAssetId,
            externalAddresses: usedAddressesMap.keys.toSet(),
            isTestnet: wallet.isTestnet,
            includeUnblindedUrl: txId != null,
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
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      // LWK accepts sat/kvByte as a double. Our RelativeFee stores sat/kwu,
      // and 1 sat/kwu = 4 sat/kvByte, so the conversion is exact integer
      // arithmetic promoted to double — no precision loss at the SDK boundary.
      final pset = await lwkWallet.buildLbtcTx(
        sats: BigInt.from(amountSat ?? 0),
        outAddress: address,
        feeRate: feeRate.satPerKvbyte,
        drain: drain,
      );
      final decoded = await lwkWallet.decodeTx(pset: pset);
      log.info(decoded.absoluteFees.toString());
      return pset;
    } catch (e) {
      if (e is lwk.LwkError) {
        if (e.msg.contains(_lwkInsufficientFundsMarker)) {
          throw InsufficientFundsException(e.msg);
        }
        // A build failure on a wallet whose confirmed L-BTC UTXO count exceeds
        // the Liquid confidential-tx input limit is almost certainly the
        // ">256 inputs" case.
        if (await _exceedsLiquidInputLimit(wallet)) {
          throw ConsolidationRequiredException(e.msg);
        }
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  /// Number of confidential-tx inputs above which a Liquid transaction can no
  /// longer be built (the true protocol maximum is 256).
  static const int maxLiquidTxInputs = 256;

  /// LWK reports a shortfall as plain text, e.g.
  /// `InsufficientFunds { missing_sats: 21, asset_id: ..., is_token: false }`.
  /// Matching the text is all the SDK gives us, so it stays in this file.
  static const String _lwkInsufficientFundsMarker = 'InsufficientFunds';

  /// Number of L-BTC UTXOs in the wallet — the count that matters for the
  /// 256-input limit (asset-filtered, mirroring lwk's `utxoStatus`). Drives
  /// consolidation detection.
  Future<int> getLbtcUtxoCount({required WalletModel wallet}) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final utxos = await lwkWallet.utxos();
      final network = wallet.isTestnet
          ? Network.liquidTestnet
          : Network.liquidMainnet;
      final lbtcAssetId = _lBtcAssetId(network);
      final lbtcCount = utxos
          .where((u) => u.unblinded.asset == lbtcAssetId)
          .length;
      return lbtcCount;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<bool> _exceedsLiquidInputLimit(WalletModel wallet) async {
    try {
      return await getLbtcUtxoCount(wallet: wallet) > maxLiquidTxInputs;
    } catch (_) {
      return false;
    }
  }

  /// Build the unsigned consolidation PSETs for a wallet, sweeping up to
  /// [maximumInputs] confirmed L-BTC UTXOs each into a single output. Returns
  /// empty when the wallet holds <= [highUtxoThreshold] UTXOs.
  ///
  /// KNOWN LIMITATION (accepted for this self-transfer-only scope, not fund-
  /// unsafe but a privacy/UX gap — see the consolidation feature's own
  /// tracking issue for a follow-up): each batch's drain address is chosen
  /// natively (lwk-dart), incrementing from `wallet.address(None)`'s
  /// sync-derived last-unused index — there is no persisted, app-level
  /// reservation of that index the way normal receive-address generation
  /// has. If `consolidate` is called again before a sync completes (e.g. two
  /// consolidation rounds in quick succession, or racing an unrelated
  /// address-generating action), the same address could be handed out
  /// twice. This is a privacy/bookkeeping concern (address reuse), not a
  /// fund-safety one — no funds can be lost, only linked on-chain.
  Future<List<String>> consolidate({
    required WalletModel wallet,
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final psets = await lwkWallet.consolidate(
        feeRate: feeRate.satPerKvbyte,
        highUtxoThreshold: highUtxoThreshold,
        maximumInputs: maximumInputs,
      );
      return psets;
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
        decoded.absoluteFees.first.value.toInt(),
      );
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<int> getAmountSentToAddress(
    String pset,
    String address, {
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final decoded = await lwkWallet.decodeTx(pset: pset);

      // Get the L-BTC asset ID for the network
      final network = wallet.isTestnet
          ? Network.liquidTestnet
          : Network.liquidMainnet;
      final lbtcAssetId = _lBtcAssetId(network);

      // Find the L-BTC balance in the decoded amounts
      final lbtcBalance = decoded.balances.firstWhere(
        (balance) => balance.assetId == lbtcAssetId,
        orElse: () => throw Exception('L-BTC balance not found in PSET'),
      );

      // The balance value in PsetAmounts represents the net balance change
      // (negative for sends). The absolute value includes both output and fees.
      // So: output amount = |balance| - fees
      final balanceAbs = lbtcBalance.value.abs();
      final fees = decoded.absoluteFees.toInt();
      final outputAmount = balanceAbs - fees;

      return outputAmount;
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

  Future<void> delete({required WalletModel wallet}) async {
    await LwkFacade.delete(wallet);
    log.fine('Deleted wallet ${wallet.id} LWK database');
  }
}

@visibleForTesting
extension NetworkX on Network {
  lwk.LiquidNetwork get lwkNetwork {
    switch (this) {
      case Network.liquidMainnet:
        return lwk.LiquidNetwork.mainnet;
      case Network.liquidTestnet:
        return lwk.LiquidNetwork.testnet;
      default:
        throw UnsupportedLwkNetworkException('$name is not supported by LWK');
    }
  }
}

class UnsupportedLwkNetworkException extends BullException {
  UnsupportedLwkNetworkException(super.message);
}
