class OrderModel {
  final String orderId;
  final String orderType;
  final String orderSubtype;
  final int orderNumber;
  final double exchangeRateAmount;
  final String exchangeRateCurrency;
  final double indexRateAmount;
  final String indexRateCurrency;
  final double payinAmount;
  final String payinCurrency;
  final double payoutAmount;
  final String payoutCurrency;
  final String orderStatus;
  final String payinStatus;
  final String payoutStatus;
  final String? scheduledPayoutTime;
  final String createdAt;
  final String? completedAt;
  final Map<String, dynamic>? message;
  final String? sentAt;
  final String payinMethod;
  final String payoutMethod;
  final String triggerType;
  final String confirmationDeadline;
  final dynamic unbatchedBuyOnchainFees;
  final String? bitcoinTransactionId;
  final String? lnUrl;
  final String? lightningVoucherExpiresAt;
  final bool isPPBitcoinOutUpdatable;
  final dynamic payinAmountChanged;

  OrderModel({
    required this.orderId,
    required this.orderType,
    required this.orderSubtype,
    required this.orderNumber,
    required this.exchangeRateAmount,
    required this.exchangeRateCurrency,
    required this.indexRateAmount,
    required this.indexRateCurrency,
    required this.payinAmount,
    required this.payinCurrency,
    required this.payoutAmount,
    required this.payoutCurrency,
    required this.orderStatus,
    required this.payinStatus,
    required this.payoutStatus,
    required this.scheduledPayoutTime,
    required this.createdAt,
    required this.completedAt,
    required this.message,
    required this.sentAt,
    required this.payinMethod,
    required this.payoutMethod,
    required this.triggerType,
    required this.confirmationDeadline,
    required this.unbatchedBuyOnchainFees,
    required this.bitcoinTransactionId,
    required this.lnUrl,
    required this.lightningVoucherExpiresAt,
    required this.isPPBitcoinOutUpdatable,
    required this.payinAmountChanged,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['orderId'] as String,
      orderType: json['orderType'] as String,
      orderSubtype: json['orderSubtype'] as String,
      orderNumber: json['orderNumber'] as int,
      exchangeRateAmount: (json['exchangeRateAmount'] as num).toDouble(),
      exchangeRateCurrency: json['exchangeRateCurrency'] as String,
      indexRateAmount: (json['indexRateAmount'] as num).toDouble(),
      indexRateCurrency: json['indexRateCurrency'] as String,
      payinAmount: (json['payinAmount'] as num).toDouble(),
      payinCurrency: json['payinCurrency'] as String,
      payoutAmount: (json['payoutAmount'] as num).toDouble(),
      payoutCurrency: json['payoutCurrency'] as String,
      orderStatus: json['orderStatus'] as String,
      payinStatus: json['payinStatus'] as String,
      payoutStatus: json['payoutStatus'] as String,
      scheduledPayoutTime: json['scheduledPayoutTime'] as String?,
      createdAt: json['createdAt'] as String,
      completedAt: json['completedAt'] as String?,
      message: json['message'] as Map<String, dynamic>?,
      sentAt: json['sentAt'] as String?,
      payinMethod: json['payinMethod'] as String,
      payoutMethod: json['payoutMethod'] as String,
      triggerType: json['triggerType'] as String,
      confirmationDeadline: json['confirmationDeadline'] as String,
      unbatchedBuyOnchainFees: json['unbatchedBuyOnchainFees'],
      bitcoinTransactionId: json['bitcoinTransactionId'] as String?,
      lnUrl: json['lnUrl'] as String?,
      lightningVoucherExpiresAt: json['lightningVoucherExpiresAt'] as String?,
      isPPBitcoinOutUpdatable: json['isPPBitcoinOutUpdatable'] as bool,
      payinAmountChanged: json['payinAmountChanged'],
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'orderType': orderType,
    'orderSubtype': orderSubtype,
    'orderNumber': orderNumber,
    'exchangeRateAmount': exchangeRateAmount,
    'exchangeRateCurrency': exchangeRateCurrency,
    'indexRateAmount': indexRateAmount,
    'indexRateCurrency': indexRateCurrency,
    'payinAmount': payinAmount,
    'payinCurrency': payinCurrency,
    'payoutAmount': payoutAmount,
    'payoutCurrency': payoutCurrency,
    'orderStatus': orderStatus,
    'payinStatus': payinStatus,
    'payoutStatus': payoutStatus,
    'scheduledPayoutTime': scheduledPayoutTime,
    'createdAt': createdAt,
    'completedAt': completedAt,
    'message': message,
    'sentAt': sentAt,
    'payinMethod': payinMethod,
    'payoutMethod': payoutMethod,
    'triggerType': triggerType,
    'confirmationDeadline': confirmationDeadline,
    'unbatchedBuyOnchainFees': unbatchedBuyOnchainFees,
    'bitcoinTransactionId': bitcoinTransactionId,
    'lnUrl': lnUrl,
    'lightningVoucherExpiresAt': lightningVoucherExpiresAt,
    'isPPBitcoinOutUpdatable': isPPBitcoinOutUpdatable,
    'payinAmountChanged': payinAmountChanged,
  };
}
