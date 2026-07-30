part of 'pay_bloc.dart';

@freezed
sealed class PayEvent with _$PayEvent {
  const factory PayEvent.started() = PayStarted;
  const factory PayEvent.recipientSelected(RecipientViewModel recipient) =
      PayRecipientSelected;
  const factory PayEvent.amountInputContinuePressed({
    required String amountInput,
    required FiatCurrency fiatCurrency,
    String? paymentDescription,
  }) = PayAmountInputContinuePressed;
  const factory PayEvent.getCadBillers({required String searchTerm}) =
      PayGetCadBillers;
  const factory PayEvent.walletSelected({required Wallet wallet}) =
      PayWalletSelected;
  const factory PayEvent.externalWalletNetworkSelected({
    required OrderBitcoinNetwork network,
  }) = PayExternalWalletNetworkSelected;
  const factory PayEvent.orderRefreshTimePassed() = PayOrderRefreshTimePassed;
  // The fee to pay comes from the committed selection on PayPaymentState, not
  // from the event: the modal writes it there and the summary row reads it
  // back, so a second copy on the event could only ever disagree (#2521).
  const factory PayEvent.sendPaymentConfirmed() = PaySendPaymentConfirmed;
  const factory PayEvent.pollOrderStatus() = PayPollOrderStatus;
  const factory PayEvent.payjoinToggled(bool enabled) = PayPayjoinToggled;
  const factory PayEvent.payjoinSessionUpdated(PayjoinSession session) =
      PayPayjoinSessionUpdated;
  const factory PayEvent.replaceByFeeChanged({required bool replaceByFee}) =
      PayReplaceByFeeChanged;
  const factory PayEvent.utxosSelected({required List<WalletUtxo> utxos}) =
      PayUtxosSelected;
  const factory PayEvent.loadUtxos() = PayLoadUtxos;
  const factory PayEvent.updateOrderStatus({required String orderId}) =
      PayUpdateOrderStatus;

  // ────── shared fee modal (FeeModalActions) ──────
  /// A preset tile was picked. Commits the tier and rebuilds the fee estimate.
  const factory PayEvent.feeOptionSelected(FeeSelection feeSelection) =
      PayFeeOptionSelected;

  /// The typed custom fee is committed — triggers the fee recalculation.
  const factory PayEvent.customFeeChanged(NetworkFee fee) = PayCustomFeeChanged;

  /// Custom-fee field changed: select `custom` without rebuilding yet, and
  /// snapshot the prior selection so dismissal can roll it back.
  const factory PayEvent.customFeeArmed(NetworkFee fee) = PayCustomFeeArmed;

  /// The custom-fee field was cleared — roll the arm back immediately so a
  /// stale typed value cannot survive to dismissal.
  const factory PayEvent.customFeeDisarmed() = PayCustomFeeDisarmed;

  /// The modal was dismissed without picking a preset: commit the armed value
  /// when it clears the relay floor, otherwise roll back.
  const factory PayEvent.customFeeFinalized() = PayCustomFeeFinalized;

  /// Debounced preview build for the typed rate (fills the `custom` slot).
  const factory PayEvent.customFeePreviewRequested(NetworkFee fee) =
      PayCustomFeePreviewRequested;

  /// Preview builds for the three presets, fired on every modal open.
  const factory PayEvent.presetFeesPreviewRequested() =
      PayPresetFeesPreviewRequested;
}
