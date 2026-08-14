import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_config.dart';

/// Result of building (but not yet broadcasting) a consolidation: the unsigned
/// PSETs plus the total network fee summed across them, for the confirm screen.
class ConsolidationPreview {
  const ConsolidationPreview({
    required this.unsignedPsets,
    required this.totalFeeSat,
  });

  final List<String> unsignedPsets;
  final int totalFeeSat;

  /// One consolidated output per transaction, so this is also the resulting
  /// UTXO count.
  int get transactionCount => unsignedPsets.length;
}

/// Orchestrates a Liquid consolidation as a set of self-transactions:
/// `consolidate` (build) → `signPset` (each) → broadcast (each, via the same
/// [BroadcastLiquidTransactionUsecase] a normal send uses).
///
/// [prepare] builds the PSETs and totals the fee for the confirm screen;
/// [broadcast] signs and broadcasts them. Thresholds/batch size come from the
/// per-boot [ConsolidationConfig] to avoid fingerprinting.
///
/// KNOWN LIMITATION (accepted for now — see
/// [LiquidWalletRepository.consolidate]'s doc comment): repeated calls to
/// [prepare] in quick succession (before a sync completes) can produce
/// batches that reuse a drain address, since address selection happens
/// natively and isn't backed by a persisted, app-level reservation. Not a
/// fund-safety issue — only an address-reuse/privacy one.
class ConsolidateLiquidWalletUsecase {
  final LiquidWalletRepository _repository;
  final BroadcastLiquidTransactionUsecase _broadcast;

  // Liquid network minrelayfee default (0.1 sat/vByte = 25 sat/kwu); the
  // consolidation self-transfer doesn't need to be fast.
  static const RelativeFee _feeRate = RelativeFee(25);

  ConsolidateLiquidWalletUsecase({
    required LiquidWalletRepository liquidWalletRepository,
    required BroadcastLiquidTransactionUsecase
    broadcastLiquidTransactionUsecase,
  }) : _repository = liquidWalletRepository,
       _broadcast = broadcastLiquidTransactionUsecase;

  Future<ConsolidationPreview> prepare({required String walletId}) async {
    try {
      final psets = await _repository.consolidate(
        walletId: walletId,
        feeRate: _feeRate,
        highUtxoThreshold: ConsolidationConfig.highUtxoThreshold,
        maximumInputs: ConsolidationConfig.maximumInputs,
      );
      var totalFeeSat = 0;
      for (final pset in psets) {
        final (_, feeSat) = await _repository.getPsetSizeAndAbsoluteFees(
          pset: pset,
        );
        totalFeeSat += feeSat;
      }
      return ConsolidationPreview(
        unsignedPsets: psets,
        totalFeeSat: totalFeeSat,
      );
    } catch (e) {
      throw ConsolidationException(e.toString());
    }
  }

  /// Sign and broadcast the previously-built PSETs, returning the txids.
  ///
  /// If a PSET partway through the list fails to sign or broadcast, the
  /// txids of whatever already succeeded are carried on the thrown
  /// [ConsolidationException.succeededTxids] rather than discarded — the
  /// caller (see [ConsolidationCubit]) uses this to avoid resubmitting an
  /// already-broadcast (and so already-spent) PSET on retry.
  Future<List<String>> broadcast({
    required String walletId,
    required List<String> unsignedPsets,
  }) async {
    final txids = <String>[];
    try {
      for (final pset in unsignedPsets) {
        final signed = await _repository.signPset(
          pset: pset,
          walletId: walletId,
        );
        txids.add(await _broadcast.execute(signed));
      }
      return txids;
    } catch (e) {
      throw ConsolidationException(e.toString(), List.unmodifiable(txids));
    }
  }
}

class ConsolidationException extends BullException {
  /// Txids that already broadcast successfully before this failure occurred
  /// (empty if the failure happened before anything broadcast, e.g. during
  /// [ConsolidateLiquidWalletUsecase.prepare]).
  final List<String> succeededTxids;

  ConsolidationException(super.message, [this.succeededTxids = const []]);
}
