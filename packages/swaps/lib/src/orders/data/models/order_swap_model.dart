class OrderSwapModel {
  final String orderId;
  final int orderNumber;
  final String payinAmount;
  final String payoutAmount;
  final String payinCurrency;
  final String payoutCurrency;
  final String payinMethod;
  final String payoutMethod;
  final String orderType;
  final String orderStatus;
  final String payinStatus;
  final String payoutStatus;
  final String messageCode;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final String? lightningInvoice;
  final String? bitcoinTransactionId;
  final String? liquidTransactionId;
  final DateTime createdAt;
  final DateTime confirmationDeadline;
  final DateTime? completedAt;
  final DateTime? sentAt;

  const OrderSwapModel({
    required this.orderId,
    required this.orderNumber,
    required this.payinAmount,
    required this.payoutAmount,
    required this.payinCurrency,
    required this.payoutCurrency,
    required this.payinMethod,
    required this.payoutMethod,
    required this.orderType,
    required this.orderStatus,
    required this.payinStatus,
    required this.payoutStatus,
    required this.messageCode,
    required this.createdAt,
    required this.confirmationDeadline,
    this.bitcoinAddress,
    this.liquidAddress,
    this.lightningInvoice,
    this.bitcoinTransactionId,
    this.liquidTransactionId,
    this.completedAt,
    this.sentAt,
  });

  factory OrderSwapModel.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    return OrderSwapModel(
      orderId: _requiredString(json['orderId'], 'orderId'),
      orderNumber: _requiredInt(json['orderNumber'], 'orderNumber'),
      payinAmount: _numberString(json['payinAmount'], 'payinAmount'),
      payoutAmount: _numberString(json['payoutAmount'], 'payoutAmount'),
      payinCurrency: _requiredString(json['payinCurrency'], 'payinCurrency'),
      payoutCurrency: _requiredString(json['payoutCurrency'], 'payoutCurrency'),
      payinMethod: _requiredString(json['payinMethod'], 'payinMethod'),
      payoutMethod: _requiredString(json['payoutMethod'], 'payoutMethod'),
      orderType: _requiredString(json['orderType'], 'orderType'),
      orderStatus: _requiredString(json['orderStatus'], 'orderStatus'),
      payinStatus: _requiredString(json['payinStatus'], 'payinStatus'),
      payoutStatus: _requiredString(json['payoutStatus'], 'payoutStatus'),
      messageCode: message is Map<String, dynamic>
          ? _requiredString(message['code'], 'message.code')
          : throw const FormatException('Missing message'),
      bitcoinAddress: json['bitcoinAddress'] as String?,
      liquidAddress: json['liquidAddress'] as String?,
      lightningInvoice: json['lightningInvoice'] as String?,
      bitcoinTransactionId: json['bitcoinTransactionId'] as String?,
      liquidTransactionId: json['liquidTransactionId'] as String?,
      createdAt: _requiredDate(json['createdAt'], 'createdAt'),
      confirmationDeadline: _requiredDate(
        json['confirmationDeadline'],
        'confirmationDeadline',
      ),
      completedAt: _optionalDate(json['completedAt'], 'completedAt'),
      sentAt: _optionalDate(json['sentAt'], 'sentAt'),
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

int _requiredInt(Object? value, String field) {
  if (value is int) return value;
  throw FormatException('Missing integer $field');
}

DateTime _requiredDate(Object? value, String field) {
  if (value is String) return DateTime.parse(value).toUtc();
  throw FormatException('Missing date $field');
}

DateTime? _optionalDate(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return DateTime.parse(value).toUtc();
  throw FormatException('Invalid date $field');
}
