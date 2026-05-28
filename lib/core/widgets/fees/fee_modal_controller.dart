import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fee_modal_controller.freezed.dart';

/// State slice the fee-selection modal reads. Whichever cubit/bloc owns
/// the actual feature state maps its own state down to this snapshot
/// once per emit — the modal never depends on the underlying
/// `SendState` / `TransferState` shape.
@freezed
abstract class FeeModalSnapshot with _$FeeModalSnapshot {
  const factory FeeModalSnapshot({
    required FeeOptions? feePresets,
    required NetworkFee? customFee,
    required FeeSelection selectedFeeOption,
    required BitcoinFeePreviewCache feePreviewCache,
    required double exchangeRate,
    required String fiatCurrencyCode,
    required int txSize,
  }) = _FeeModalSnapshot;
  const FeeModalSnapshot._();
}

/// Read-only port the shared fee modal subscribes to. Adapters
/// (cubits/blocs) implement [snapshot] / [snapshots] by mapping their
/// own state down to a [FeeModalSnapshot].
abstract class FeeModalViewState {
  /// Synchronous current value — used by `StreamBuilder.initialData`
  /// and by widget `initState` to avoid a frame of empty state.
  FeeModalSnapshot get snapshot;

  /// Live view, re-emits on every relevant change to the underlying
  /// feature state.
  Stream<FeeModalSnapshot> get snapshots;
}

/// Command port the shared fee modal dispatches against. Adapters
/// (cubits) implement these as direct method calls; adapters (blocs)
/// implement them by adding the corresponding event.
///
/// Kept separate from [FeeModalViewState] so a future caller — e.g.
/// a read-only summary widget — could subscribe to the state without
/// being handed a way to mutate it.
abstract class FeeModalActions {
  /// Builds the three preset PSBTs in parallel and writes the slots
  /// into the cache. Idempotent; safe to call on every modal open.
  void requestPresetPreviews();

  /// Debounced custom-fee preview build. Caller fires per keystroke;
  /// the cache's `custom` slot receives the real `psbt.fee()` once.
  void requestCustomFeePreview(NetworkFee fee);

  /// Eager arm — `selectedFeeOption: custom`, `customFee: fee`, no
  /// rebuild. Rolled back via [finalizeArmedCustomFee] when the user
  /// dismisses without typing a valid value.
  void armCustomFee(NetworkFee fee);

  /// Called on modal dismissal. Commits the typed value (rebuilding
  /// the tx) when it clears `NetworkFeeRelayPolicy.minRelay`;
  /// otherwise rolls back to the pre-arm selection.
  void finalizeArmedCustomFee();

  /// Preset picked. Commits + triggers the rebuild.
  void selectFeeOption(FeeSelection selection);
}
