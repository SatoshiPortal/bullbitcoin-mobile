class RateHistoryRequestModel {
  final String fromCurrency;
  final String toCurrency;
  final String interval;
  final DateTime? fromDate;
  final DateTime? toDate;

  RateHistoryRequestModel({
    required this.fromCurrency,
    required this.toCurrency,
    required this.interval,
    this.fromDate,
    this.toDate,
  });

  Map<String, dynamic> toApiParams() {
    final fromDateMs =
        fromDate?.millisecondsSinceEpoch ??
        DateTime.now()
            .subtract(const Duration(days: 365))
            .millisecondsSinceEpoch;
    final toDateMs =
        toDate?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;

    return {
      'element': {
        'fromCurrency': fromCurrency,
        'toCurrency': toCurrency,
        'interval': interval,
        'fromDate': fromDateMs.toString(),
        'toDate': toDateMs.toString(),
      },
    };
  }
}
