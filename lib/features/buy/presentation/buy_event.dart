part of 'buy_bloc.dart';

@freezed
sealed class BuyEvent with _$BuyEvent {
  const factory BuyEvent.started() = _BuyStarted;
  const factory BuyEvent.amountInputChanged(String amount) =
      _BuyAmountInputChanged;
  const factory BuyEvent.currencyInputChanged(String currencyCode) =
      _BuyCurrencyInputChanged;
  const factory BuyEvent.fiatCurrencyInputToggled() =
      _BuyFiatCurrencyInputToggled;
  const factory BuyEvent.selectedWalletChanged(Wallet? wallet) =
      _BuySelectedWalletChanged;
  const factory BuyEvent.bitcoinAddressInputChanged(String bitcoinAddress) =
      _BuyBitcoinAddressInputChanged;
  const factory BuyEvent.createOrder() = _BuyCreateOrder;
  const factory BuyEvent.refreshOrder({String? orderId}) = _BuyRefreshOrder;
  const factory BuyEvent.confirmOrder() = _BuyConfirmOrder;
  const factory BuyEvent.accelerateTransactionPressed(String orderId) =
      _BuyAccelerateTransactionPressed;
  const factory BuyEvent.accelerateTransactionConfirmed() =
      _BuyAccelerateTransactionConfirmed;
  const BuyEvent._();
}
