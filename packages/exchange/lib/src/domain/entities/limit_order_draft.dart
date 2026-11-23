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
}
