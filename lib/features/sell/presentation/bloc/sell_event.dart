part of 'sell_bloc.dart';

@freezed
sealed class SellEvent with _$SellEvent {
  const factory SellEvent.started() = SellStarted;
  const factory SellEvent.amountInputContinuePressed({
    required String amountInput,
    required bool isFiatCurrencyInput,
    required FiatCurrency fiatCurrency,
  }) = SellAmountInputContinuePressed;
  const factory SellEvent.walletSelected({required Wallet wallet}) =
      SellWalletSelected;
  const factory SellEvent.externalWalletNetworkSelected({
    required OrderBitcoinNetwork network,
  }) = SellExternalWalletNetworkSelected;
  const factory SellEvent.orderRefreshTimePassed() = SellOrderRefreshTimePassed;
  // The fee to pay comes from the committed selection on SellPaymentState, not
  // from the event: the modal writes it there and the summary row reads it
  // back, so a second copy on the event could only ever disagree (#2521).
  const factory SellEvent.sendPaymentConfirmed() = SellSendPaymentConfirmed;
  const factory SellEvent.pollOrderStatus() = SellPollOrderStatus;
  const factory SellEvent.replaceByFeeChanged({required bool replaceByFee}) =
      SellReplaceByFeeChanged;
  const factory SellEvent.utxosSelected({required List<WalletUtxo> utxos}) =
      SellUtxosSelected;
  const factory SellEvent.loadUtxos() = SellLoadUtxos;

  // ────── shared fee modal (FeeModalActions) ──────
  /// A preset tile was picked. Commits the tier and rebuilds the fee estimate.
  const factory SellEvent.feeOptionSelected(FeeSelection feeSelection) =
      SellFeeOptionSelected;

  /// The typed custom fee is committed — triggers the fee recalculation.
  const factory SellEvent.customFeeChanged(NetworkFee fee) =
      SellCustomFeeChanged;

  /// Custom-fee field changed: select `custom` without rebuilding yet, and
  /// snapshot the prior selection so dismissal can roll it back.
  const factory SellEvent.customFeeArmed(NetworkFee fee) = SellCustomFeeArmed;

  /// The custom-fee field was cleared — roll the arm back immediately so a
  /// stale typed value cannot survive to dismissal.
  const factory SellEvent.customFeeDisarmed() = SellCustomFeeDisarmed;

  /// The modal was dismissed without picking a preset: commit the armed value
  /// when it clears the relay floor, otherwise roll back.
  const factory SellEvent.customFeeFinalized() = SellCustomFeeFinalized;

  /// Debounced preview build for the typed rate (fills the `custom` slot).
  const factory SellEvent.customFeePreviewRequested(NetworkFee fee) =
      SellCustomFeePreviewRequested;

  /// Preview builds for the three presets, fired on every modal open.
  const factory SellEvent.presetFeesPreviewRequested() =
      SellPresetFeesPreviewRequested;
}
