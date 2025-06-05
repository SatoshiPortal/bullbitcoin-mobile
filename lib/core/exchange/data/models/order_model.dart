import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

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

  Order toEntity() {
    Network network;
    if (payoutMethod.toLowerCase().contains('lightning')) {
      network = Network.lightning;
    } else if (payoutMethod.toLowerCase().contains('liquid')) {
      network = Network.liquid;
    } else {
      network = Network.bitcoin;
    }

    final params = {
      'orderId': orderId,
      'orderSubtype': orderSubtype,
      'orderNumber': orderNumber,
      'exchangeRateAmount': exchangeRateAmount,
      'exchangeRateCurrency': exchangeRateCurrency,
      'indexRateAmount': indexRateAmount,
      'indexRateCurrency': indexRateCurrency,
      'payinAmount': payinAmount,
      'payinCurrency': FiatCurrency.fromCode(payinCurrency),
      'payoutAmount': payoutAmount,
      'payoutCurrency': payoutCurrency,
      'orderStatus': orderStatus,
      'payinStatus': payinStatus,
      'payoutStatus': payoutStatus,
      'scheduledPayoutTime': scheduledPayoutTime,
      'createdAt': DateTime.parse(createdAt),
      'completedAt': completedAt != null ? DateTime.parse(completedAt!) : null,
      'message': message,
      'sentAt': sentAt != null ? DateTime.parse(sentAt!) : null,
      'payinMethod': payinMethod,
      'payoutMethod': payoutMethod,
      'triggerType': triggerType,
      'confirmationDeadline': DateTime.parse(confirmationDeadline),
      'unbatchedBuyOnchainFees': unbatchedBuyOnchainFees,
      'bitcoinTransactionId': bitcoinTransactionId,
      'lnUrl': lnUrl,
      'lightningVoucherExpiresAt':
          lightningVoucherExpiresAt != null
              ? DateTime.parse(lightningVoucherExpiresAt!)
              : null,
      'isPPBitcoinOutUpdatable': isPPBitcoinOutUpdatable,
      'payinAmountChanged': payinAmountChanged,
      'network': network,
    };

    return orderType == 'Buy Bitcoin'
        ? Order.buy(
              orderId: params['orderId'] as String,
              orderSubtype: params['orderSubtype'] as String,
              orderNumber: params['orderNumber'] as int,
              exchangeRateAmount: params['exchangeRateAmount'] as double,
              exchangeRateCurrency: params['exchangeRateCurrency'] as String,
              indexRateAmount: params['indexRateAmount'] as double,
              indexRateCurrency: params['indexRateCurrency'] as String,
              payinAmount: params['payinAmount'] as double,
              payinCurrency: params['payinCurrency'] as FiatCurrency,
              payoutAmount: params['payoutAmount'] as double,
              payoutCurrency: params['payoutCurrency'] as String,
              orderStatus: params['orderStatus'] as String,
              payinStatus: params['payinStatus'] as String,
              payoutStatus: params['payoutStatus'] as String,
              scheduledPayoutTime: params['scheduledPayoutTime'] as String?,
              createdAt: params['createdAt'] as DateTime,
              completedAt: params['completedAt'] as DateTime?,
              message: params['message'] as Map<String, dynamic>?,
              sentAt: params['sentAt'] as DateTime?,
              payinMethod: params['payinMethod'] as String,
              payoutMethod: params['payoutMethod'] as String,
              triggerType: params['triggerType'] as String,
              confirmationDeadline: params['confirmationDeadline'] as DateTime,
              unbatchedBuyOnchainFees: params['unbatchedBuyOnchainFees'],
              bitcoinTransactionId: params['bitcoinTransactionId'] as String?,
              lnUrl: params['lnUrl'] as String?,
              lightningVoucherExpiresAt:
                  params['lightningVoucherExpiresAt'] as DateTime?,
              isPPBitcoinOutUpdatable:
                  params['isPPBitcoinOutUpdatable'] as bool,
              payinAmountChanged: params['payinAmountChanged'],
              network: params['network'] as Network,
            )
            as BuyOrder
        : Order.sell(
              orderId: params['orderId'] as String,
              orderSubtype: params['orderSubtype'] as String,
              orderNumber: params['orderNumber'] as int,
              exchangeRateAmount: params['exchangeRateAmount'] as double,
              exchangeRateCurrency: params['exchangeRateCurrency'] as String,
              indexRateAmount: params['indexRateAmount'] as double,
              indexRateCurrency: params['indexRateCurrency'] as String,
              payinAmount: params['payinAmount'] as double,
              payinCurrency: params['payinCurrency'] as FiatCurrency,
              payoutAmount: params['payoutAmount'] as double,
              payoutCurrency: params['payoutCurrency'] as String,
              orderStatus: params['orderStatus'] as String,
              payinStatus: params['payinStatus'] as String,
              payoutStatus: params['payoutStatus'] as String,
              scheduledPayoutTime: params['scheduledPayoutTime'] as String?,
              createdAt: params['createdAt'] as DateTime,
              completedAt: params['completedAt'] as DateTime?,
              message: params['message'] as Map<String, dynamic>?,
              sentAt: params['sentAt'] as DateTime?,
              payinMethod: params['payinMethod'] as String,
              payoutMethod: params['payoutMethod'] as String,
              triggerType: params['triggerType'] as String,
              confirmationDeadline: params['confirmationDeadline'] as DateTime,
              unbatchedBuyOnchainFees: params['unbatchedBuyOnchainFees'],
              bitcoinTransactionId: params['bitcoinTransactionId'] as String?,
              lnUrl: params['lnUrl'] as String?,
              lightningVoucherExpiresAt:
                  params['lightningVoucherExpiresAt'] as DateTime?,
              isPPBitcoinOutUpdatable:
                  params['isPPBitcoinOutUpdatable'] as bool,
              payinAmountChanged: params['payinAmountChanged'],
              network: params['network'] as Network,
            )
            as SellOrder;
  }
}
