class RateHistoryRequestModel {
  final String fromCurrency;
  final String toCurrency;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String interval;

  RateHistoryRequestModel({
    required this.fromCurrency,
    required this.toCurrency,
    this.fromDate,
    this.toDate,
    required this.interval,
  });

  Map<String, dynamic> toApiParams() {
    final params = <String, dynamic>{
      'fromCurrency': fromCurrency,
      'toCurrency': toCurrency,
      'interval': interval,
    };

    if (fromDate != null) {
      params['fromDate'] = fromDate!.millisecondsSinceEpoch.toString();
    }

    if (toDate != null) {
      params['toDate'] = toDate!.millisecondsSinceEpoch.toString();
    }

    return {'element': params};
  }
}
