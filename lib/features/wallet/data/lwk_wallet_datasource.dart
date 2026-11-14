import 'package:sync/diagnostics.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:flutter/material.dart';
import 'package:bull_sdk/lwk.dart' as lwk;

class LwkWalletDatasource {
  final Future<lwk.Wallet> Function(WalletModel) _readWallet;

  LwkWalletDatasource({required this._readWallet});

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
  Future<int> _lbtcUtxoCount({required WalletModel wallet}) async {
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
      return await _lbtcUtxoCount(wallet: wallet) > maxLiquidTxInputs;
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
