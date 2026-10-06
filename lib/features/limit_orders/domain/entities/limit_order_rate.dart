final class LimitOrderRate {
  final String currencyCode;
  final double indexPrice;
  final double userPrice;

  LimitOrderRate({
    required this.currencyCode,
    required this.indexPrice,
    required this.userPrice,
  }) {
    if (currencyCode.isEmpty) {
      throw ArgumentError.value(currencyCode, 'currencyCode');
    }
    if (indexPrice <= 0) throw ArgumentError.value(indexPrice, 'indexPrice');
    if (userPrice <= 0) throw ArgumentError.value(userPrice, 'userPrice');
  }

  double priceForDiscount(double discountPercent) {
    final discount = discountPercent.clamp(1, 99);
    return indexPrice * (1 - discount / 100);
  }

  double discountForPrice(double targetPrice) {
    final clampedPrice = targetPrice.clamp(
      indexPrice * 0.01,
      indexPrice * 0.99,
    );
    return ((1 - clampedPrice / indexPrice) * 100).clamp(1, 99);
  }

  double estimatedBuyPrice(double targetPrice) =>
      targetPrice * (userPrice / indexPrice);
}
