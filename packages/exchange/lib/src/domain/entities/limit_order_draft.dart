import 'order.dart';

final class LimitOrderDraft {
  final double limitPrice;
  final double fiatAmount;
  final FiatCurrency currency;
  final String address;
  final double estimatedBtcAmount;

  LimitOrderDraft({
    required this.limitPrice,
    required this.fiatAmount,
    required this.currency,
    required this.address,
  }) : estimatedBtcAmount = fiatAmount / limitPrice {
    if (limitPrice <= 0) {
      throw ArgumentError.value(limitPrice, 'limitPrice');
    }
    if (fiatAmount <= 0) {
      throw ArgumentError.value(fiatAmount, 'fiatAmount');
    }
    if (address.trim().isEmpty) {
      throw ArgumentError.value(address, 'address');
    }
  }

  /// What was sent, as the journal records it and as a re-read matches it
  /// ([findCreatedLimitOrder]): amounts with the currency's decimals.
  Map<String, String> get journalRequest => {
    'limitPrice': limitPrice.toStringAsFixed(currency.decimals),
    'fiatAmount': fiatAmount.toStringAsFixed(currency.decimals),
    'currency': currency.code,
    'address': address,
  };
}
