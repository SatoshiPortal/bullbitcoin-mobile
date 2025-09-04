part of 'pay_bloc.dart';

@freezed
sealed class PayEvent with _$PayEvent {
  const factory PayEvent.started() = PayStarted;
  const factory PayEvent.newRecipientAdded() = PayNewRecipientAdded;
  const factory PayEvent.createNewRecipient(NewRecipient newRecipient) =
      PayCreateNewRecipient;
  const factory PayEvent.recipientSelected(Recipient recipient) =
      PayRecipientSelected;
  const factory PayEvent.amountInputContinuePressed({
    required String amountInput,
    required FiatCurrency fiatCurrency,
  }) = PayAmountInputContinuePressed;
  const factory PayEvent.getCadBillers({required String searchTerm}) =
      PayGetCadBillers;
  const factory PayEvent.walletSelected({required Wallet wallet}) =
      PayWalletSelected;
  const factory PayEvent.externalWalletNetworkSelected({
    required OrderBitcoinNetwork network,
  }) = PayExternalWalletNetworkSelected;
  const factory PayEvent.orderRefreshTimePassed() = PayOrderRefreshTimePassed;
  const factory PayEvent.sendPaymentConfirmed({
    required FeeSelection feeSelection,
    NetworkFee? customFee,
  }) = PaySendPaymentConfirmed;
  const factory PayEvent.pollOrderStatus() = PayPollOrderStatus;
  const factory PayEvent.replaceByFeeChanged({required bool replaceByFee}) =
      PayReplaceByFeeChanged;
  const factory PayEvent.utxoSelected({required WalletUtxo utxo}) =
      PayUtxoSelected;
  const factory PayEvent.loadUtxos() = PayLoadUtxos;
}
