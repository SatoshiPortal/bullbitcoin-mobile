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
  const factory SellEvent.sendPaymentConfirmed({
    required FeeSelection feeSelection,
    NetworkFee? customFee,
  }) = SellSendPaymentConfirmed;
  const factory SellEvent.pollOrderStatus() = SellPollOrderStatus;
  const factory SellEvent.replaceByFeeChanged({required bool replaceByFee}) =
      SellReplaceByFeeChanged;
  const factory SellEvent.utxoSelected({required WalletUtxo utxo}) =
      SellUtxoSelected;
  const factory SellEvent.loadUtxos() = SellLoadUtxos;
}
