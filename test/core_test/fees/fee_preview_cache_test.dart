import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the cache value object that replaced the 11 nullable preview
/// fields on `SendState` / `TransferState`. Locks in the lifecycle the
/// cubit and bloc depend on: empty slots are not cache-ready, the
/// per-selection accessor matches FeeSelection, and `withSlot` round-trips
/// through `slotFor`.
void main() {
  group('BitcoinFeePreviewSlot', () {
    test('default slot is not cache-ready', () {
      const slot = BitcoinFeePreviewSlot();
      expect(slot.isCacheReady, isFalse);
    });

    test('slot with fee but no PSBT is not cache-ready', () {
      // Mid-build state: the use case wrote a fee but `psbt` and `txSize`
      // didn't make it. createTransaction must NOT short-circuit on this.
      const slot = BitcoinFeePreviewSlot(feeSat: 1234);
      expect(slot.isCacheReady, isFalse);
    });

    test('slot with PSBT + txSize is cache-ready', () {
      const slot = BitcoinFeePreviewSlot(
        feeSat: 1234,
        unsignedPsbt: 'aabbcc',
        txSize: 140,
      );
      expect(slot.isCacheReady, isTrue);
    });
  });

  group('BitcoinFeePreviewCache', () {
    test('empty cache has empty slots for every FeeSelection', () {
      const cache = BitcoinFeePreviewCache.empty;
      for (final sel in FeeSelection.values) {
        expect(cache.slotFor(sel), const BitcoinFeePreviewSlot());
        expect(cache.slotFor(sel).isCacheReady, isFalse);
      }
      expect(cache.presetsLoading, isFalse);
      expect(cache.customLoading, isFalse);
    });

    test('withSlot round-trips through slotFor', () {
      const fastest = BitcoinFeePreviewSlot(
        feeSat: 1000,
        unsignedPsbt: 'aa',
        txSize: 140,
      );
      const slow = BitcoinFeePreviewSlot(
        feeSat: 14,
        unsignedPsbt: 'bb',
        txSize: 140,
      );
      const empty = BitcoinFeePreviewCache.empty;
      final filled = empty
          .withSlot(FeeSelection.fastest, fastest)
          .withSlot(FeeSelection.slow, slow);
      expect(filled.slotFor(FeeSelection.fastest), fastest);
      expect(filled.slotFor(FeeSelection.slow), slow);
      // Untouched slots remain empty.
      expect(filled.slotFor(FeeSelection.economic).isCacheReady, isFalse);
      expect(filled.slotFor(FeeSelection.custom).isCacheReady, isFalse);
    });
  });
}
