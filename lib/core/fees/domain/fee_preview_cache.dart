import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fee_preview_cache.freezed.dart';

/// One slot of the four-tile fee-preview cache. Holds the real fee read
/// from a built unsigned PSBT (`psbt.fee()`), plus the PSBT bytes and
/// txSize so the commit path can rebroadcast the exact tx the user saw
/// — defeating BDK's randomized coin selection.
///
/// An empty slot (`feeSat == null && unsignedPsbt == null && txSize == null`)
/// means the modal has not built this preset for the current input shape
/// yet; the UI shimmers.
@freezed
abstract class BitcoinFeePreviewSlot with _$BitcoinFeePreviewSlot {
  const factory BitcoinFeePreviewSlot({
    int? feeSat,
    String? unsignedPsbt,
    int? txSize,
  }) = _BitcoinFeePreviewSlot;
  const BitcoinFeePreviewSlot._();

  /// Whether this slot can be reused at commit time. Both PSBT and txSize
  /// must be present — `feeSat` alone is a display value, not enough to
  /// short-circuit the build.
  bool get isCacheReady => unsignedPsbt != null && txSize != null;
}

/// The full four-slot fee-preview cache, plus the two loading flags the
/// UI shimmers off. Replaces 11 nullable fields on `SendState` /
/// `TransferState` with one composite value object so the cache lifecycle
/// is reasonable about and the matrix of partial states stops bleeding
/// through state.copyWith calls.
///
/// Indexed by [FeeSelection]; both states expose `state.feePreviewCache`
/// to selectors and read slots via [slotFor].
@freezed
abstract class BitcoinFeePreviewCache with _$BitcoinFeePreviewCache {
  const factory BitcoinFeePreviewCache({
    @Default(BitcoinFeePreviewSlot()) BitcoinFeePreviewSlot fastest,
    @Default(BitcoinFeePreviewSlot()) BitcoinFeePreviewSlot economic,
    @Default(BitcoinFeePreviewSlot()) BitcoinFeePreviewSlot slow,
    @Default(BitcoinFeePreviewSlot()) BitcoinFeePreviewSlot custom,
    @Default(false) bool presetsLoading,
    @Default(false) bool customLoading,
  }) = _BitcoinFeePreviewCache;
  const BitcoinFeePreviewCache._();

  /// Empty cache — no slot has been built. Use as the default on the
  /// owning state and as the value to `copyWith` into on invalidation.
  static const empty = BitcoinFeePreviewCache();

  BitcoinFeePreviewSlot slotFor(FeeSelection selection) => switch (selection) {
    FeeSelection.fastest => fastest,
    FeeSelection.economic => economic,
    FeeSelection.slow => slow,
    FeeSelection.custom => custom,
  };

  BitcoinFeePreviewCache withSlot(
    FeeSelection selection,
    BitcoinFeePreviewSlot slot,
  ) => switch (selection) {
    FeeSelection.fastest => copyWith(fastest: slot),
    FeeSelection.economic => copyWith(economic: slot),
    FeeSelection.slow => copyWith(slow: slot),
    FeeSelection.custom => copyWith(custom: slot),
  };
}
