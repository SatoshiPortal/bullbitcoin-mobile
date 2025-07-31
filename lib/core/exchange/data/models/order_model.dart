import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

class OrderModel {
  final String orderId;
  final String orderType;
  final String? orderSubtype;
  final int orderNumber;
  final double exchangeRateAmount;
  final String exchangeRateCurrency;
  final double? indexRateAmount;
  final String? indexRateCurrency;
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
  final String? bitcoinTransactionId;
  final String? lnUrl;
  final String? lightningVoucherExpiresAt;
  final bool? isPPBitcoinOutUpdatable;
  final dynamic payinAmountChanged;
  final String? lightningInvoice;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final String? liquidTransactionId;
  final String? lightningAddress;
  final String? beneficiaryName;
  final String? beneficiaryLabel;
  final String? beneficiaryAccountNumber;
  final String? beneficiaryETransferAddress;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? paymentDescription;
  final double? unbatchedBuyOnchainFees;

  OrderModel({
    required this.orderId,
    required this.orderType,
    this.orderSubtype,
    required this.orderNumber,
    required this.exchangeRateAmount,
    required this.exchangeRateCurrency,
    this.indexRateAmount,
    this.indexRateCurrency,
    required this.payinAmount,
    required this.payinCurrency,
    required this.payoutAmount,
    required this.payoutCurrency,
    required this.orderStatus,
    required this.payinStatus,
    required this.payoutStatus,
    this.scheduledPayoutTime,
    required this.createdAt,
    this.completedAt,
    required this.message,
    this.sentAt,
    required this.payinMethod,
    required this.payoutMethod,
    required this.triggerType,
    required this.confirmationDeadline,
    this.bitcoinTransactionId,
    this.lnUrl,
    this.lightningVoucherExpiresAt,
    this.isPPBitcoinOutUpdatable,
    this.payinAmountChanged,
    this.lightningInvoice,
    this.bitcoinAddress,
    this.liquidAddress,
    this.liquidTransactionId,
    this.lightningAddress,
    this.beneficiaryName,
    this.beneficiaryLabel,
    this.beneficiaryAccountNumber,
    this.beneficiaryETransferAddress,
    this.securityQuestion,
    this.securityAnswer,
    this.paymentDescription,
    this.unbatchedBuyOnchainFees,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['orderId'] as String,
      orderType: json['orderType'] as String,
      orderSubtype: json['orderSubtype'] as String?,
      orderNumber: json['orderNumber'] as int,
      exchangeRateAmount: (json['exchangeRateAmount'] as num).toDouble(),
      exchangeRateCurrency: json['exchangeRateCurrency'] as String,
      indexRateAmount: (json['indexRateAmount'] as num?)?.toDouble(),
      indexRateCurrency: json['indexRateCurrency'] as String?,
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
      bitcoinTransactionId: json['bitcoinTransactionId'] as String?,
      lnUrl: json['lnUrl'] as String?,
      lightningVoucherExpiresAt: json['lightningVoucherExpiresAt'] as String?,
      isPPBitcoinOutUpdatable: json['isPPBitcoinOutUpdatable'] as bool?,
      payinAmountChanged: json['payinAmountChanged'] as Map<String, dynamic>?,
      lightningInvoice: json['lightningInvoice'] as String?,
      bitcoinAddress: json['bitcoinAddress'] as String?,
      liquidAddress: json['liquidAddress'] as String?,
      liquidTransactionId: json['liquidTransactionId'] as String?,
      lightningAddress: json['lightningAddress'] as String?,
      beneficiaryName: json['beneficiaryName'] as String?,
      beneficiaryLabel: json['beneficiaryLabel'] as String?,
      beneficiaryAccountNumber: json['beneficiaryAccountNumber'] as String?,
      beneficiaryETransferAddress:
          json['beneficiaryETransferAddress'] as String?,
      securityQuestion: json['securityQuestion'] as String?,
      securityAnswer: json['securityAnswer'] as String?,
      paymentDescription: json['paymentDescription'] as String?,
      unbatchedBuyOnchainFees: json['unbatchedBuyOnchainFees'] as double?,
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
    'bitcoinTransactionId': bitcoinTransactionId,
    'lnUrl': lnUrl,
    'lightningVoucherExpiresAt': lightningVoucherExpiresAt,
    'isPPBitcoinOutUpdatable': isPPBitcoinOutUpdatable,
    'payinAmountChanged': payinAmountChanged,
    'lightningInvoice': lightningInvoice,
    'bitcoinAddress': bitcoinAddress,
    'liquidAddress': liquidAddress,
    'liquidTransactionId': liquidTransactionId,
    'lightningAddress': lightningAddress,
    'beneficiaryName': beneficiaryName,
    'beneficiaryLabel': beneficiaryLabel,
    'beneficiaryAccountNumber': beneficiaryAccountNumber,
    'beneficiaryETransferAddress': beneficiaryETransferAddress,
    'securityQuestion': securityQuestion,
    'securityAnswer': securityAnswer,
    'paymentDescription': paymentDescription,
    'unbatchedBuyOnchainFees': unbatchedBuyOnchainFees,
  };

  Order toEntity({required bool isTestnet}) {
    final orderMsg =
        message != null && message is Map<String, dynamic>
            ? OrderMessage(
              code: message?['code']?.toString() ?? '',
              message: message?['message']?.toString() ?? '',
            )
            : OrderMessage(code: '', message: '');

    final orderTypeEnum = OrderType.fromValue(orderType);
    final payinMethodEnum = OrderPaymentMethod.fromValue(payinMethod);
    final payoutMethodEnum = OrderPaymentMethod.fromValue(payoutMethod);
    final orderStatusEnum = OrderStatus.fromValue(orderStatus);
    final payinStatusEnum = OrderPayinStatus.fromValue(payinStatus);
    final payoutStatusEnum = OrderPayoutStatus.fromValue(payoutStatus);
    final confirmationDeadlineDt = DateTime.parse(confirmationDeadline);
    final createdAtDt = DateTime.parse(createdAt);
    final completedAtDt =
        completedAt != null ? DateTime.tryParse(completedAt!) : null;
    final sentAtDt = sentAt != null ? DateTime.tryParse(sentAt!) : null;
    final scheduledPayoutTimeDt =
        scheduledPayoutTime != null
            ? DateTime.tryParse(scheduledPayoutTime!)
            : null;
    final lightningVoucherExpiresAtDt =
        lightningVoucherExpiresAt != null
            ? DateTime.tryParse(lightningVoucherExpiresAt!)
            : null;
    final payinAmountChangedObj =
        payinAmountChanged != null && payinAmountChanged is Map<String, dynamic>
            ? PayinAmountChanged(
              requestedAmount:
                  (payinAmountChanged['requestedAmount'] as num?)?.toDouble() ??
                  0,
              receivedAmount:
                  (payinAmountChanged['receivedAmount'] as num?)?.toDouble() ??
                  0,
            )
            : null;

    switch (orderTypeEnum) {
      case OrderType.buy:
        return Order.buy(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isPPBitcoinOutUpdatable: isPPBitcoinOutUpdatable,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
          unbatchedBuyOnchainFees: unbatchedBuyOnchainFees,
          isTestnet: isTestnet,
        );
      case OrderType.sell:
        return Order.sell(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isPPBitcoinOutUpdatable: isPPBitcoinOutUpdatable,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.fiatPayment:
        return Order.fiatPayment(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          isTestnet: isTestnet,
        );
      case OrderType.funding:
        return Order.funding(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          payinAmountChanged: payinAmountChangedObj,
          isTestnet: isTestnet,
        );
      case OrderType.withdraw:
        return Order.withdraw(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.reward:
        return Order.reward(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isPPBitcoinOutUpdatable: isPPBitcoinOutUpdatable,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.refund:
        return Order.refund(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.balanceAdjustment:
        return Order.balanceAdjustment(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
    }
  }
}
