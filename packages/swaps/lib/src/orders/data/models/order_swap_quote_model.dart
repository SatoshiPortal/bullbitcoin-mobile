class OrderSwapQuoteModel {
  final String inAmount;
  final String outAmount;
  final String inCurrency;
  final String outCurrency;
  final List<String> feePercents;
  final List<String> warnings;

  const OrderSwapQuoteModel({
    required this.inAmount,
    required this.outAmount,
    required this.inCurrency,
    required this.outCurrency,
    required this.feePercents,
    required this.warnings,
  });

  factory OrderSwapQuoteModel.fromJson(Map<String, dynamic> json) {
    final fees = json['orderFees'];
    final warning = json['warning'];
    return OrderSwapQuoteModel(
      inAmount: _numberString(json['inAmount'], 'inAmount'),
      outAmount: _numberString(json['outAmount'], 'outAmount'),
      inCurrency: _requiredString(
        json['inPaymentProcessorCurrencyCode'],
        'inPaymentProcessorCurrencyCode',
      ),
      outCurrency: _requiredString(
        json['outPaymentProcessorCurrencyCode'],
        'outPaymentProcessorCurrencyCode',
      ),
      feePercents: fees is List
          ? fees
                .whereType<Map<String, dynamic>>()
                .map((fee) => _numberString(fee['percent'], 'percent'))
                .toList(growable: false)
          : const [],
      warnings: warning is List
          ? warning.map((value) => value.toString()).toList(growable: false)
          : const [],
    );
  }
}

String _numberString(Object? value, String field) {
  if (value is num) return value.toString();
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing numeric $field');
}

String _requiredString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing $field');
}
