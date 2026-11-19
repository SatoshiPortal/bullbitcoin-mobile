/// UI projection of a supported fiat currency and its current price.
final class BullAmountCurrency {
  final String code;
  final int decimals;
  final double? price;
  final DateTime? priceAt;
  final bool loading;

  const BullAmountCurrency({
    required this.code,
    required this.decimals,
    this.price,
    this.priceAt,
    this.loading = false,
  });

  bool get hasPrice {
    final rate = price;
    return rate != null && rate.isFinite && rate > 0 && priceAt != null;
  }
}

/// One edit or representation change. Only an edit changes the quantity; the receiving feature owns the conversion record and freezes it when proceeding.
final class BullAmountInputValue {
  final BigInt? sats;
  final String currencyCode;
  final String text;

  /// Present only for an edit, so a projection cannot be mistaken for a new user conversion.
  final double? price;
  final DateTime? priceAt;
  final bool isValid;
  final bool isEdit;
  final bool isMax;

  const BullAmountInputValue({
    required this.sats,
    required this.currencyCode,
    required this.text,
    required this.price,
    required this.priceAt,
    required this.isValid,
    required this.isEdit,
    required this.isMax,
  });
}
