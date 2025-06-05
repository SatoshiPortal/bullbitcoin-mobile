part of 'buy_bloc.dart';

@freezed
sealed class BuyEvent with _$BuyEvent {
  const factory BuyEvent.started() = _BuyStarted;
  const factory BuyEvent.amountInputChanged(String amount) =
      _BuyAmountInputChanged;
  const factory BuyEvent.currencyInputChanged(String currencyCode) =
      _BuyCurrencyInputChanged;
  const factory BuyEvent.selectedWalletChanged(Wallet? wallet) =
      _BuySelectedWalletChanged;
  const factory BuyEvent.bitcoinAddressInputChanged(String bitcoinAddress) =
      _BuyBitcoinAddressInputChanged;
  const factory BuyEvent.createOrder() = _BuyCreateOrder;
  const BuyEvent._();
}
