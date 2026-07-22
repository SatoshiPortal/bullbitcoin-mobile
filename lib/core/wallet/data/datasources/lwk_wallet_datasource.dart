import 'dart:async';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_facade.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

  /// [stopAtIndex]: scan the descriptor at least up to this derivation
  /// index, instead of stopping at LWK's default 20-consecutive-unused gap
  /// limit. Must be passed whenever the app has handed out addresses beyond
  /// what LWK has ever seen as used (see
  /// `LiquidReceiveAddressIndexDatasource`): e.g. a consolidation reserves
  /// 2 fresh addresses per batch without syncing in between, so a multi-batch
  /// run can leave funded addresses further out than a default gap-limit
  /// scan will ever look — making those UTXOs (and the balance they carry)
  /// invisible to the wallet until a deep-enough scan runs.
  Future<void> sync({
    required WalletModel wallet,
    required ElectrumConnection electrumServer,
    int? stopAtIndex,
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
        await lwkWallet.sync_(
          electrumUrl: electrumServer.url,
          validateDomain: electrumServer.validateDomain,
          stopAtIndex: stopAtIndex,
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
    String? toAddress,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final transactions = await lwkWallet.txs();
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
          final (inputs, outputs) = await (
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
          final netAmountSat = isToSelf
              ? sumOutputs - changeAmountInToSelf
              : isIncoming
              ? finalBalance
              : finalBalance.abs() - tx.fee.toInt();

          return WalletTransactionModel(
            txId: tx.txid,
            isIncoming: isIncoming,
            amountSat: netAmountSat,
            feeSat: tx.fee.toInt(),
            vsize: tx.vsize.toInt(),
            confirmationTimestamp: tx.timestamp,
            isToSelf: isToSelf,
            inputs: inputs,
            outputs: outputs,
            isLiquid: true,
            isTestnet: wallet.isTestnet,
            unblindedUrl: tx.unblindedUrl,
            isRbf: false,
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

  /// Number of confidential-tx inputs above which a Liquid transaction can no
  /// longer be built (the true protocol maximum is 256).
  static const int maxLiquidTxInputs = 256;

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

  /// Confirmed L-BTC UTXOs — the candidates for consolidation batching.
  /// Asset+height filtered directly against the live LWK UTXO set (mirrors
  /// the filter the old `Wallet.consolidate()` RPC used to apply internally).
  ///
  /// Distinct from [getLbtcUtxoCount], which counts ALL L-BTC UTXOs
  /// (confirmed or not) for the send-blocking input-limit check — consolidate
  /// candidates must be confirmed, but a pending send still has to account
  /// for every UTXO it could end up spending.
  Future<List<WalletUtxoModel>> getConfirmedLbtcUtxos({
    required WalletModel wallet,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final utxos = await lwkWallet.utxos();
      final network = wallet.isTestnet
          ? Network.liquidTestnet
          : Network.liquidMainnet;
      final lbtcAssetId = _lBtcAssetId(network);
      return utxos
          .where((u) => u.unblinded.asset == lbtcAssetId && u.height != null)
          .map(
            (u) => WalletUtxoModel.liquid(
              txId: u.outpoint.txid,
              vout: u.outpoint.vout,
              amountSat: u.unblinded.value,
              scriptPubkey: u.scriptPubkey,
              standardAddress: u.address.standard,
              confidentialAddress: u.address.confidential,
              confirmations: 1,
            ),
          )
          .toList();
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  /// Build a PSET spending exactly [utxos], paying [outputs], with any
  /// leftover L-BTC value (after outputs + fee) swept to [drainToAddress] if
  /// set. General-purpose builder for custom output shapes — e.g. a
  /// consolidation batch's drain output plus a decoy output.
  Future<String> buildCustomTx({
    required WalletModel wallet,
    required List<Outpoint> utxos,
    required List<LiquidTxOutput> outputs,
    String? drainToAddress,
    required RelativeFee feeRate,
  }) async {
    try {
      final lwkWallet = await LwkFacade.createPublicWallet(wallet);
      final pset = await lwkWallet.buildCustomTx(
        utxos: utxos
            .map((o) => lwk.OutPoint(txid: o.txId, vout: o.vout))
            .toList(),
        outputs: outputs
            .map(
              (o) => lwk.TxOutputSpec(
                address: o.address,
                satoshi: BigInt.from(o.satoshi),
                assetId: o.assetId,
              ),
            )
            .toList(),
        drainTo: drainToAddress,
        feeRate: feeRate.satPerKvbyte,
      );
      return pset;
    } catch (e) {
      if (e is lwk.LwkError) {
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

  /// The output index (vout) of the first output in [pset] with a plaintext
  /// value of exactly [satoshi] — used to identify a known-amount output
  /// (e.g. a decoy) after building a custom tx, without assuming output
  /// ordering. A PSET (unlike a finalized tx) still carries the plaintext
  /// amount for outputs this wallet itself constructed, so no unblinding is
  /// needed. Returns null if no output matches.
  int? findOutputIndexByAmount({required String pset, required int satoshi}) {
    try {
      final decoded = lwk.PartiallySignedElementsTransaction.fromString(
        psetString: pset,
      );
      final outputs = decoded.getOutputs();
      final target = BigInt.from(satoshi);
      for (var i = 0; i < outputs.length; i++) {
        final output = outputs[i];
        // Exclude the fee output (empty scriptPubkey) so an implausibly
        // small fee can never be mistaken for the decoy.
        if (output.amount == target && output.scriptPubkey.isNotEmpty) {
          return i;
        }
      }
      return null;
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
      final lwkWallet = await LwkFacade.createPrivateWallet(wallet);
      final signedPset = await lwkWallet.signTx(
        network: wallet.isTestnet
            ? lwk.LiquidNetwork.testnet
            : lwk.LiquidNetwork.mainnet,
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
      if (decoded.absoluteFees.isEmpty) {
        // Should never happen for a well-formed single-asset (L-BTC) PSET —
        // surfaced as a clear, specific message instead of an opaque
        // `StateError: No element` from `.first`, so a caller's failure
        // banner/log actually says what went wrong.
        throw Exception(
          'PSET decoded with no fee entries for any asset (absoluteFees was '
          'empty)',
        );
      }
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
