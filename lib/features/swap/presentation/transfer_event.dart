part of 'transfer_bloc.dart';

@freezed
sealed class TransferEvent with _$TransferEvent {
  const factory TransferEvent.started() = TransferStarted;
  const factory TransferEvent.walletsChanged({
    required Wallet fromWallet,
    required Wallet toWallet,
  }) = TransferWalletsChanged;
  const factory TransferEvent.amountChanged(String amount) =
      TransferAmountChanged;
  const factory TransferEvent.swapCreated(String amount) = TransferSwapCreated;
  const factory TransferEvent.confirmed() = TransferConfirmed;
  const factory TransferEvent.sendToExternalToggled(bool enabled) =
      TransferSendToExternalToggled;
  const factory TransferEvent.externalAddressChanged(String address) =
      TransferExternalAddressChanged;
  const factory TransferEvent.receiveExactAmountToggled(bool enabled) =
      TransferReceiveExactAmountToggled;
  const factory TransferEvent.replaceByFeeChanged(bool replaceByFee) =
      TransferReplaceByFeeChanged;
  const factory TransferEvent.utxosSelected(List<WalletUtxo> utxos) =
      TransferUtxosSelected;
  const factory TransferEvent.loadUtxos() = TransferLoadUtxos;
  const factory TransferEvent.feeOptionSelected(FeeSelection feeSelection) =
      TransferFeeOptionSelected;
  const factory TransferEvent.customFeeChanged(NetworkFee fee) =
      TransferCustomFeeChanged;

  /// Eagerly commits `selectedFeeOption: custom` + the typed [fee] so the
  /// preset tiles deselect while the user is still editing — without
  /// triggering the PSBT rebuild that `customFeeChanged` does. The actual
  /// commit happens on `customFeeChanged` (Confirm button).
  const factory TransferEvent.customFeeArmed(NetworkFee fee) =
      TransferCustomFeeArmed;

  /// Rolls back to the pre-arm `selectedFeeOption`/`customFee` if no
  /// `customFeeChanged` ran. Used when the user picks a preset tile
  /// (the preset commit clears the arm separately).
  const factory TransferEvent.customFeeDisarmed() = TransferCustomFeeDisarmed;

  /// Called by the fee modal's parent when the user dismisses without
  /// picking a preset. Commits the typed custom rate if armed and
  /// above the 0.1 sat/vB floor; rolls back otherwise. The replacement
  /// for the old explicit "Confirm Custom Fee" button.
  const factory TransferEvent.customFeeFinalized() = TransferCustomFeeFinalized;

  /// Builds an unsigned PSBT at the typed rate and stores the slot
  /// (real fee + cached PSBT + txSize) into
  /// `feePreviewCache.custom`. Debounced from the widget.
  const factory TransferEvent.customFeePreviewRequested(NetworkFee fee) =
      TransferCustomFeePreviewRequested;

  /// Fires 3 prepare-only builds (Fastest / Economic / Slow) so the
  /// modal can render real per-preset fees instead of rate × vsize.
  const factory TransferEvent.presetFeesPreviewRequested() =
      TransferPresetFeesPreviewRequested;
  const factory TransferEvent.orderSwapUpdated(
    Result<OrderSwapRecord, SwapFailure> result,
  ) = TransferOrderSwapUpdated;
}
