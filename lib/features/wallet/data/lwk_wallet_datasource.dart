import 'package:transaction_sync/diagnostics.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:flutter/material.dart';
import 'package:bull_sdk/lwk.dart' as lwk;

class LwkWalletDatasource {
  final Future<lwk.Wallet> Function(WalletModel) _readWallet;

  LwkWalletDatasource({required this._readWallet});

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    try {
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.balance,
        () => _readWallet(wallet),
      );
      final balances = await lwkWallet.balances();

      final assetId = await lwkWallet.policyAsset();
      final lBtcAssetBalance = balances.firstWhere((balance) {
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
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    try {
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.utxos,
        () => _readWallet(wallet),
      );
      final utxos = await lwkWallet.utxos();

      final assetId = await lwkWallet.policyAsset();
      final unspent = utxos
          .where((utxo) => utxo.unblinded.asset == assetId)
          .map((utxo) {
            return WalletUtxoModel.liquid(
              txId: utxo.outpoint.txid,
              vout: utxo.outpoint.vout,
              amountSat: utxo.unblinded.value,
              scriptPubkey: utxo.scriptPubkey,
              standardAddress: utxo.address.standard,
              confidentialAddress: utxo.address.confidential,
              blockHeight: utxo.height,
            );
          });

      return unspent.toList();
    } catch (e) {
      if (e is lwk.LwkError) {
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  Future<({String standard, String confidential, int index})>
  getLastUnusedAddress({required WalletModel wallet}) async {
    try {
      final lwkWallet = await _readWallet(wallet);
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
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.addressList,
        () => _readWallet(wallet),
      );
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
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.addressList,
        () => _readWallet(wallet),
      );
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
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.addressList,
        () => _readWallet(wallet),
      );
      final txs = await lwkWallet.txs();
      final txOutputLists = txs.map((tx) => tx.outputs).toList();
      final outputs = txOutputLists.expand((list) => list).toList();
      if (outputs.isEmpty) {
        return false;
      }
      return outputs.any(
        (output) =>
            output.address.confidential == address ||
            output.address.standard == address,
      );
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
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.addressList,
        () => _readWallet(wallet),
      );
      final utxos = await lwkWallet.utxos();
      final addressBalances = <String, BigInt>{};

      for (final utxo in utxos) {
        final assetId = await lwkWallet.policyAsset();
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

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    try {
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.transactions,
        () => _readWallet(wallet),
      );
      final transactions = await lwkWallet.txs();
      final usedAddressesMap = await _getUsedAddressesMap(wallet: wallet);
      final lbtcAssetId = await lwkWallet.policyAsset();
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
          final toDestination = sumOutputs - changeAmountInToSelf;
          // LWK lists only this wallet's outputs and cannot list change
          // addresses, so a redeposit to an unlisted address of the wallet has
          // no recognised destination. With a single L-BTC output, that output
          // is the destination; any other ambiguous case stays unresolved.
          final soleOutput = tx.outputs.length == 1 ? tx.outputs.first : null;
          final soleRedepositSat =
              tx.kind == 'redeposit' &&
                  soleOutput != null &&
                  soleOutput.unblinded.asset == lbtcAssetId
              ? soleOutput.unblinded.value.toInt()
              : null;
          final netAmountSat = isToSelf
              ? toDestination == 0
                    ? soleRedepositSat ?? 0
                    : toDestination
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
            network: wallet.network,
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

  Future<String> buildPset({
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    required WalletModel wallet,
    Set<Outpoint>? selectedInputs,
  }) async {
    try {
      if (!drain && amountSat == null) {
        throw Exception('Amount required unless draining');
      }
      final lwkWallet = await LeaseDiagnostics.from(
        LeaseSource.sendBuild,
        () => _readWallet(wallet),
      );
      // LWK accepts sat/kvByte as a double. Our RelativeFee stores sat/kwu,
      // and 1 sat/kwu = 4 sat/kvByte, so the conversion is exact integer
      // arithmetic promoted to double — no precision loss at the SDK boundary.
      final pset = selectedInputs == null
          ? await lwkWallet.buildLbtcTx(
              sats: BigInt.from(amountSat ?? 0),
              outAddress: address,
              feeRate: feeRate.satPerKvbyte,
              drain: drain,
            )
          : await lwkWallet.buildCustomTx(
              utxos: [
                for (final input in selectedInputs)
                  lwk.OutPoint(txid: input.txId, vout: input.vout),
              ],
              outputs: [
                if (!drain)
                  lwk.TxOutputSpec(
                    address: address,
                    satoshi: BigInt.from(
                      amountSat ?? (throw Exception('Missing amount')),
                    ),
                  ),
              ],
              drainTo: drain ? address : null,
              feeRate: feeRate.satPerKvbyte,
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
        if (selectedInputs != null
            ? selectedInputs.length > maxLiquidTxInputs
            : await _exceedsLiquidInputLimit(wallet)) {
          throw ConsolidationRequiredException(e.msg);
        }
        rethrow;
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
      final lwkWallet = await _readWallet(wallet);
      final utxos = await lwkWallet.utxos();
      final lbtcAssetId = await lwkWallet.policyAsset();
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
    Set<Outpoint> unspendable = const {},
  }) async {
    try {
      final lwkWallet = await _readWallet(wallet);
      // LWK's consolidation helper cannot exclude frozen coins. Build the
      // same balanced batches with explicit inputs when exclusions exist.
      if (unspendable.isNotEmpty) {
        if (maximumInputs <= 0) {
          throw ArgumentError.value(maximumInputs, 'maximumInputs');
        }
        final assetId = await lwkWallet.policyAsset();
        final coins = (await lwkWallet.utxos())
            .where(
              (coin) =>
                  coin.unblinded.asset == assetId &&
                  coin.height != null &&
                  !unspendable.contains((
                    txId: coin.outpoint.txid,
                    vout: coin.outpoint.vout,
                  )),
            )
            .toList();
        if (coins.length <= highUtxoThreshold) return [];
        final limit = maximumInputs.clamp(1, 250);
        final batches = (coins.length / limit).ceil();
        final batchSize = (coins.length / batches).ceil();
        final start = (await lwkWallet.addressLastUnused()).index;
        if (start == null) {
          throw Exception('Missing consolidation address index');
        }
        final psets = <String>[];
        for (var offset = 0; offset < coins.length; offset += batchSize) {
          final address = await lwkWallet.address(
            index: start + offset ~/ batchSize,
          );
          try {
            psets.add(
              await lwkWallet.buildCustomTx(
                utxos: coins
                    .skip(offset)
                    .take(batchSize)
                    .map((coin) => coin.outpoint)
                    .toList(),
                outputs: [],
                drainTo: address.confidential,
                feeRate: feeRate.satPerKvbyte,
              ),
            );
          } on lwk.LwkError catch (error) {
            if (!error.msg.contains(_lwkInsufficientFundsMarker)) rethrow;
          }
        }
        if (psets.isEmpty) {
          throw NoSpendableUtxoException(
            'Consolidation inputs cannot cover the fee',
          );
        }
        return psets;
      }
      final psets = await lwkWallet.consolidate(
        feeRate: feeRate.satPerKvbyte,
        highUtxoThreshold: highUtxoThreshold,
        maximumInputs: maximumInputs,
      );
      return psets;
    } catch (e) {
      if (e is lwk.LwkError) {
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  Set<Outpoint> getPsetInputs(String pset) => {
    for (final input in lwk.PartiallySignedElementsTransaction.fromString(
      psetString: pset,
    ).extractTx().getInputs())
      (txId: input.txid, vout: input.vout),
  };

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
      final lwkWallet = await _readWallet(wallet);
      final decoded = await lwkWallet.decodeTx(pset: pset);

      // Get the L-BTC asset ID for the network
      final lbtcAssetId = await lwkWallet.policyAsset();

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
}

extension NetworkX on Network {
  lwk.LiquidNetwork get lwkNetwork {
    switch (this) {
      case Network.liquidMainnet:
        return lwk.LiquidNetwork.mainnet;
      case Network.liquidTestnet:
        return lwk.LiquidNetwork.testnet;
      case Network.liquidRegtest:
        return lwk.LiquidNetwork.regtest;
      default:
        throw UnsupportedLwkNetworkException('$name is not supported by LWK');
    }
  }
}

class UnsupportedLwkNetworkException extends BullException {
  UnsupportedLwkNetworkException(super.message);
}
