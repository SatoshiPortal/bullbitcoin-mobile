final class LimitOrderDraft {
  final double limitPrice;
  final double fiatAmount;
  final String currencyCode;
  final String address;
  final double estimatedBtcAmount;

  LimitOrderDraft({
    required this.limitPrice,
    required this.fiatAmount,
    required this.currencyCode,
    required this.address,
  }) : estimatedBtcAmount = fiatAmount / limitPrice {
    if (limitPrice <= 0) {
      throw ArgumentError.value(limitPrice, 'limitPrice');
    }
    if (fiatAmount <= 0) {
      throw ArgumentError.value(fiatAmount, 'fiatAmount');
    }
    if (currencyCode.isEmpty) {
      throw ArgumentError.value(currencyCode, 'currencyCode');
    }
    if (address.trim().isEmpty) {
      throw ArgumentError.value(address, 'address');
    }
  }
}
