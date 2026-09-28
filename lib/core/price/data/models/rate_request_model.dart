class RateRequestModel {
  final String fromCurrency;
  final String toCurrency;

  RateRequestModel({required this.fromCurrency, required this.toCurrency});

  Map<String, dynamic> toApiParams() {
    return {
      'element': {'fromCurrency': fromCurrency, 'toCurrency': toCurrency},
    };
  }
}
