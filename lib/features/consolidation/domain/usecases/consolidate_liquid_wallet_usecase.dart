import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_config.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:meta/meta.dart';

/// One consolidation batch: the unsigned PSET (draining a group of UTXOs to
/// one real output, plus a small decoy output) and which output index within
/// it is the decoy — needed to freeze the right UTXO once it's broadcast.
class ConsolidationBatch {
  final String pset;
  final int decoyVout;

  const ConsolidationBatch({required this.pset, required this.decoyVout});
}

/// Result of building (but not yet broadcasting) a consolidation: the unsigned
/// batches plus the total network fee summed across them, for the confirm
/// screen.
class ConsolidationPreview {
  final List<ConsolidationBatch> batches;
  final int totalFeeSat;

  /// How many UTXOs are actually being consolidated (confirmed, unfrozen —
  /// the same filtered candidate list batching was computed from). This is
  /// the "outputs before" number the confirm screen shows; it's carried
  /// alongside the batches themselves rather than recomputed separately, so
  /// the two numbers can never disagree — a frozen UTXO isn't just excluded
  /// from being spent, it doesn't count as "there" at all for this screen.
  final int utxoCount;

  const ConsolidationPreview({
    required this.batches,
    required this.totalFeeSat,
    required this.utxoCount,
  });

  /// One consolidated output per transaction, so this is also the resulting
  /// UTXO count.
  int get transactionCount => batches.length;
}

/// Result of signing and broadcasting a [ConsolidationPreview]'s batches.
class ConsolidationBroadcastResult {
  final List<String> txids;

  /// How many decoy outputs failed to freeze (best-effort bookkeeping, not a
  /// fund-safety issue — the broadcasts still succeeded). Non-zero means the
  /// user may want to freeze them manually via the Coins screen.
  final int unfrozenDecoyCount;

  const ConsolidationBroadcastResult({
    required this.txids,
    required this.unfrozenDecoyCount,
  });
}

/// Orchestrates a Liquid consolidation as a set of self-transactions, each
/// with two outputs: the real drained output, and a small decoy output (so
/// the tx isn't an obvious many-in/one-out self-transfer signature).
///
/// `consolidate` (build, via `buildCustomTx`) → `signPset` (each) →
/// broadcast (each, via the same [BroadcastLiquidTransactionUsecase] a normal
/// send uses) → freeze the decoy (best-effort).
///
/// [prepare] builds the batches and totals the fee for the confirm screen;
/// [broadcast] signs, broadcasts, and freezes the decoys. Thresholds/batch
/// size/decoy amount come from the per-boot [ConsolidationConfig] to avoid
/// fingerprinting.
class ConsolidateLiquidWalletUsecase {
  final LiquidWalletRepository _repository;
  final BroadcastLiquidTransactionUsecase _broadcast;
  final WalletUtxoRepository _utxoRepository;
  final WalletAddressRepository _addressRepository;
  final GetWalletUsecase _getWallet;
  final SyncWalletUsecase _sync;

  // Liquid network minrelayfee default (0.1 sat/vByte = 25 sat/kwu); the
  // consolidation self-transfer doesn't need to be fast.
  static const RelativeFee _feeRate = RelativeFee(25);

  ConsolidateLiquidWalletUsecase({
    required LiquidWalletRepository liquidWalletRepository,
    required BroadcastLiquidTransactionUsecase
    broadcastLiquidTransactionUsecase,
    required WalletUtxoRepository walletUtxoRepository,
    required WalletAddressRepository walletAddressRepository,
    required GetWalletUsecase getWalletUsecase,
    required SyncWalletUsecase syncWalletUsecase,
  }) : _repository = liquidWalletRepository,
       _broadcast = broadcastLiquidTransactionUsecase,
       _utxoRepository = walletUtxoRepository,
       _addressRepository = walletAddressRepository,
       _getWallet = getWalletUsecase,
       _sync = syncWalletUsecase;

  /// Number of batches and UTXOs-per-batch so that no batch exceeds
  /// [maxInputs] and batches are as evenly sized as possible. Mirrors the
  /// math the old `lwk` `consolidate()` RPC used to do on the Rust side —
  /// batching now happens here so each batch can carry a decoy output.
  ///
  /// Deliberately `n = ceil(total / maxInputs)`, not the literal
  /// `round(total / maxInputs)` from the original design discussion:
  /// round-half-up can produce a batch that *exceeds* [maxInputs] (e.g.
  /// 300 UTXOs / 250 max rounds to a single 300-input batch, over the safety
  /// cap), whereas ceiling never does. `@visibleForTesting` since this pure
  /// math is worth exercising directly at a realistic scale (hundreds of
  /// UTXOs) without needing to fake that many outpoints through [prepare].
  @visibleForTesting
  static (int, int) batchSizes(int total, int maxInputs) {
    final n = (total + maxInputs - 1) ~/ maxInputs;
    final perBatch = (total + n - 1) ~/ n;
    return (n, perBatch);
  }

  @visibleForTesting
  static List<List<OutpointAmount>> distributeByValue(
    List<OutpointAmount> candidates,
    int n,
  ) {
    final sorted = [...candidates]
      ..sort((a, b) => b.amountSat.compareTo(a.amountSat));
    final buckets = List.generate(n, (_) => <OutpointAmount>[]);
    for (var i = 0; i < sorted.length; i++) {
      buckets[i % n].add(sorted[i]);
    }
    return buckets;
  }

  @useResult
  Future<Result<ConsolidationPreview, ConsolidationFailure>> prepare({
    required String walletId,
  }) async {
    // LiquidWalletRepository still throws (rule #11's staged-migration
    // exception: "the feature use-case when wrapping a shared core repo that
    // still throws" is the try/catch boundary) — core/wallet itself isn't
    // being converted to Result/Failure in this PR, only this new feature is.
    try {
      final confirmedUtxos = await _repository.getConfirmedLbtcOutpointAmounts(
        walletId: walletId,
      );
      // A frozen UTXO doesn't exist for consolidation purposes — it's
      // excluded from both the "outputs before" count and the batches
      // themselves, not just from being spent (e.g. a previous
      // consolidation's own decoy outputs, already frozen, must never be
      // pulled back into a later consolidation).
      final frozenOutpoints = (await _utxoRepository.getAllFrozenOutpoints())
          .toSet();
      final usableUtxos = confirmedUtxos
          .where((u) => !frozenOutpoints.contains((txId: u.txId, vout: u.vout)))
          .toList();

      if (usableUtxos.length <= ConsolidationConfig.highUtxoThreshold) {
        return Ok(
          ConsolidationPreview(
            batches: const [],
            totalFeeSat: 0,
            utxoCount: usableUtxos.length,
          ),
        );
      }

      final (n, _) = batchSizes(
        usableUtxos.length,
        ConsolidationConfig.maximumInputs,
      );
      // Distributed by value (not chunked by position) so no batch ends up
      // made entirely of dust that can't cover its own decoy + fee — see
      // distributeByValue's doc comment for the incident this fixes.
      final valueBalancedBatches = distributeByValue(usableUtxos, n);

      final batches = <ConsolidationBatch>[];
      var totalFeeSat = 0;
      for (var i = 0; i < n; i++) {
        final chunk = valueBalancedBatches[i]
            .map((u) => (txId: u.txId, vout: u.vout))
            .toList();
        if (chunk.isEmpty) continue;

        // Reserved through WalletAddressRepository (not a raw
        // getLastUnusedAddressIndex/getAddressByIndex pair) so two batches —
        // or a consolidation running close in time to any other
        // address-generating event — can never be handed the same address.
        // LWK's own "last unused" is purely sync-derived and doesn't
        // advance until a sync completes, so calling it twice in a row
        // (once per batch here, or once here and once elsewhere) can return
        // the same index both times; the reservation datasource is the one
        // thing that actually prevents that collision.
        final mainAddress = await _addressRepository.generateNewReceiveAddress(
          walletId: walletId,
        );
        final decoyAddress = await _addressRepository.generateNewReceiveAddress(
          walletId: walletId,
        );

        final pset = await _repository.buildCustomTx(
          walletId: walletId,
          utxos: chunk,
          outputs: [
            LiquidTxOutput(
              address: decoyAddress.address,
              satoshi: ConsolidationConfig.decoySats,
            ),
          ],
          drainToAddress: mainAddress.address,
          feeRate: _feeRate,
        );

        final decoyVout = _repository.findOutputIndexByAmount(
          pset: pset,
          satoshi: ConsolidationConfig.decoySats,
        );
        if (decoyVout == null) {
          return Err(
            ConsolidationBuildFailure(
              'Could not locate the decoy output in batch ${i + 1}/$n',
            ),
          );
        }

        final (_, feeSat) = await _repository.getPsetSizeAndAbsoluteFees(
          pset: pset,
        );
        totalFeeSat += feeSat;

        batches.add(ConsolidationBatch(pset: pset, decoyVout: decoyVout));
      }

      return Ok(
        ConsolidationPreview(
          batches: batches,
          totalFeeSat: totalFeeSat,
          utxoCount: usableUtxos.length,
        ),
      );
    } catch (e) {
      return Err(ConsolidationBuildFailure(e.toString()));
    }
  }

  /// Sign, broadcast, and (best-effort) freeze the decoy of each batch.
  @useResult
  Future<Result<ConsolidationBroadcastResult, ConsolidationFailure>> broadcast({
    required String walletId,
    required List<ConsolidationBatch> batches,
  }) async {
    final txids = <String>[];
    var unfrozenDecoyCount = 0;
    for (final batch in batches) {
      final String signed;
      try {
        signed = await _repository.signPset(
          pset: batch.pset,
          walletId: walletId,
        );
      } catch (e) {
        // txids collected so far already broadcast — a retry must not
        // resend them (see ConsolidationSignFailure.succeededTxids). Sync
        // now if any did, same reasoning as the full-success path below.
        if (txids.isNotEmpty) await _syncPastThisRound(walletId);
        return Err(
          ConsolidationSignFailure(List.unmodifiable(txids), e.toString()),
        );
      }
      final String txid;
      try {
        txid = await _broadcast.execute(signed);
      } catch (e) {
        if (txids.isNotEmpty) await _syncPastThisRound(walletId);
        return Err(
          ConsolidationBroadcastFailure(List.unmodifiable(txids), e.toString()),
        );
      }
      txids.add(txid);

      // Best-effort: freezing the decoy is bookkeeping, not fund safety — a
      // failure here doesn't undo the successful broadcast, but the caller
      // surfaces unfrozenDecoyCount so the user knows to freeze it manually.
      try {
        await _utxoRepository.freezeUtxos(
          walletId: walletId,
          outpoints: [(txId: txid, vout: batch.decoyVout)],
        );
      } catch (_) {
        unfrozenDecoyCount++;
      }
    }

    if (txids.isNotEmpty) {
      await _syncPastThisRound(walletId);
    }
    return Ok(
      ConsolidationBroadcastResult(
        txids: txids,
        unfrozenDecoyCount: unfrozenDecoyCount,
      ),
    );
  }

  Future<void> _syncPastThisRound(String walletId) async {
    try {
      final wallet = await _getWallet.execute(walletId);
      if (wallet != null) await _sync.execute(wallet);
    } catch (_) {
      // Best-effort: a failure here just means the next sync's default
      // gap-limit scan may lag one round behind — not fatal, but worth
      // being aware nothing else currently backstops it.
    }
  }
}
