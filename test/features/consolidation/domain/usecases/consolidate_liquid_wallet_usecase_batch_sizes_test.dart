import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [ConsolidateLiquidWalletUsecase.batchSizes] directly, at the
/// realistic UTXO counts (hundreds, approaching/exceeding the 256 confidential
/// -tx input limit) the underlying GitHub issue is actually about — the
/// wallet-level `prepare()`/`broadcast()` tests use tiny fixtures (a handful
/// of outpoints) because they're driven by the TEMP=2 test config, so this
/// file is where the batching *math* itself is proven correct at scale,
/// independent of whatever `ConsolidationConfig` happens to be set to.
void main() {
  group('batchSizes', () {
    test('the issue\'s own worked example: 1126 UTXOs / 250 max inputs -> 5 '
        'batches of 226, 226, 226, 226, 222 (never exceeding 250)', () {
      final (n, perBatch) = ConsolidateLiquidWalletUsecase.batchSizes(
        1126,
        250,
      );

      expect(n, 5);
      expect(perBatch, 226);
      // Simulate the actual skip/take split prepare() does, to confirm
      // every batch is non-empty and within the cap, and all batches
      // together account for every UTXO exactly once.
      final sizes = List.generate(n, (i) {
        final start = i * perBatch;
        final end = (start + perBatch).clamp(0, 1126);
        return end - start;
      });
      expect(sizes, [226, 226, 226, 226, 222]);
      expect(sizes.reduce((a, b) => a + b), 1126);
      expect(sizes.every((s) => s <= 250), isTrue);
    });

    test('a wallet just over the 256-input crash limit (300 UTXOs / 250 max) '
        'never produces an over-cap batch — the deliberate ceiling-vs-round '
        'divergence: round-half-up would give a single 300-input batch here, '
        'violating the cap; ceiling correctly splits into two', () {
      final (n, perBatch) = ConsolidateLiquidWalletUsecase.batchSizes(300, 250);

      expect(n, 2);
      expect(perBatch, 150);
      expect(perBatch, lessThanOrEqualTo(250));
    });

    test('an exact multiple never over-allocates a trailing empty batch', () {
      final (n, perBatch) = ConsolidateLiquidWalletUsecase.batchSizes(500, 250);

      expect(n, 2);
      expect(perBatch, 250);
    });

    test('one UTXO over a single batch\'s capacity still needs 2 batches', () {
      final (n, perBatch) = ConsolidateLiquidWalletUsecase.batchSizes(251, 250);

      expect(n, 2);
      expect(perBatch, lessThanOrEqualTo(250));
      // 251 split across 2 batches as evenly as possible: 126 + 125.
      expect(perBatch, 126);
    });

    test('a UTXO count exactly at the cap needs only 1 batch', () {
      final (n, perBatch) = ConsolidateLiquidWalletUsecase.batchSizes(250, 250);

      expect(n, 1);
      expect(perBatch, 250);
    });

    test(
      'no batch ever exceeds maxInputs across a range of realistic sizes',
      () {
        const maxInputs = 250;
        for (final total in [
          1,
          2,
          249,
          250,
          251,
          256,
          500,
          1000,
          1126,
          10000,
        ]) {
          final (n, perBatch) = ConsolidateLiquidWalletUsecase.batchSizes(
            total,
            maxInputs,
          );
          expect(
            perBatch,
            lessThanOrEqualTo(maxInputs),
            reason:
                'total=$total produced a perBatch of $perBatch > $maxInputs',
          );
          expect(
            n * perBatch,
            greaterThanOrEqualTo(total),
            reason: 'total=$total: $n batches of $perBatch cannot cover it',
          );
        }
      },
    );
  });
}
