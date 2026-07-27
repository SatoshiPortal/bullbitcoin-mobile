import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [ConsolidateLiquidWalletUsecase.distributeByValue] directly —
/// the fix for the incident where several 1-sat leftover decoy UTXOs (no
/// longer frozen) landed together in one batch under the old sequential
/// chunking, producing a batch whose total value couldn't cover its own
/// decoy output + fee (`InsufficientFunds`).
void main() {
  group('distributeByValue', () {
    test('never puts all the dust in one bucket when a large UTXO exists', () {
      final candidates = [
        (txId: 'large', vout: 0, amountSat: 1000000),
        ...List.generate(8, (i) => (txId: 'dust$i', vout: 0, amountSat: 1)),
      ];

      final buckets = ConsolidateLiquidWalletUsecase.distributeByValue(
        candidates,
        2,
      );

      expect(buckets, hasLength(2));
      final bucketHasLarge = buckets
          .map((b) => b.any((u) => u.txId == 'large'))
          .toList();
      expect(bucketHasLarge.where((has) => has).length, 1);
      for (final bucket in buckets) {
        expect(
          bucket.any((u) => u.txId.startsWith('dust')),
          isTrue,
          reason: 'every bucket should get some dust too',
        );
      }
    });

    test('every candidate appears in exactly one bucket — none dropped, '
        'none duplicated', () {
      final candidates = List.generate(
        21,
        (i) => (txId: 'tx$i', vout: 0, amountSat: i * 100),
      );

      final buckets = ConsolidateLiquidWalletUsecase.distributeByValue(
        candidates,
        3,
      );

      final all = buckets.expand((b) => b).toList();
      expect(all.length, 21);
      expect(
        all.map((u) => u.txId).toSet(),
        candidates.map((u) => u.txId).toSet(),
      );
    });

    test('bucket sizes never differ by more than 1 (round-robin dealing '
        'preserves the same balance batchSizes already guarantees)', () {
      final candidates = List.generate(
        10,
        (i) => (txId: 'tx$i', vout: 0, amountSat: 100),
      );

      final buckets = ConsolidateLiquidWalletUsecase.distributeByValue(
        candidates,
        3,
      );

      final sizes = buckets.map((b) => b.length).toList();
      expect(
        sizes.reduce((a, b) => a > b ? a : b) -
            sizes.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1),
      );
    });

    test('a single bucket just gets everything, still sorted by nothing '
        'in particular (n=1 is the "no split needed" case)', () {
      final candidates = List.generate(
        4,
        (i) => (txId: 'tx$i', vout: 0, amountSat: i),
      );

      final buckets = ConsolidateLiquidWalletUsecase.distributeByValue(
        candidates,
        1,
      );

      expect(buckets, hasLength(1));
      expect(buckets.single, hasLength(4));
    });

    test('with uniform amounts, dealing degenerates to a simple round-robin '
        '(order-only), which is harmless when value-balance is moot', () {
      final candidates = List.generate(
        6,
        (i) => (txId: 'tx$i', vout: 0, amountSat: 500),
      );

      final buckets = ConsolidateLiquidWalletUsecase.distributeByValue(
        candidates,
        2,
      );

      expect(buckets[0], hasLength(3));
      expect(buckets[1], hasLength(3));
    });
  });
}
