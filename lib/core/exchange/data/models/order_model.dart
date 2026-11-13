import 'package:bb_mobile/core/exchange/data/exchange_json_decoder.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

class OrderModel {
  final String orderId;
  final String orderType;
  final String? orderSubtype;
  final int orderNumber;
  final double? exchangeRateAmount;
  final String? exchangeRateCurrency;
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
  // Nullable per the server contract: not every order carries a trigger type
  // (the exchange web client reads it defensively too).
  final String? triggerType;
  final String? confirmationDeadline;
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
  // The customer's payjoin BIP21 URI. On a buy the app generates it and sends
  // it with the order; on a sell or a payment the backend produces it. Kept as
  // the raw string: it is handed to the payjoin PDK verbatim, and re-encoding a
  // canonical URI is how it gets corrupted.
  final String? bip21URI;
  // Raw JSON, like `message` and `payinAmountChanged` above; turned into
  // OrderPayjoinDetails in toEntity.
  final Map<String, dynamic>? payjoinDetails;
  final String? referenceNumber;
  final String? originName;
  final String? originCedula;

  OrderModel({
    required this.orderId,
    required this.orderType,
    this.orderSubtype,
    required this.orderNumber,
    this.exchangeRateAmount,
    this.exchangeRateCurrency,
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
    this.triggerType,
    this.confirmationDeadline,
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
    this.bip21URI,
    this.payjoinDetails,
    this.referenceNumber,
    this.originName,
    this.originCedula,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: decodeExchangeJson<String>(json['orderId']),
      orderType: decodeExchangeJson<String>(json['orderType']),
      orderSubtype: decodeExchangeJson<String?>(json['orderSubtype']),
      orderNumber: decodeExchangeJson<int>(json['orderNumber']),
      // Nullable per the server contract: reward, funding, refund and
      // balance-adjustment orders carry no exchange rate and no deadline. The
      // amounts and the status strings are read defensively for the same
      // reason — an admin-initiated order has no real pay-in side.
      exchangeRateAmount: (decodeExchangeJson<num?>(
        json['exchangeRateAmount'],
      ))?.toDouble(),
      exchangeRateCurrency: decodeExchangeJson<String?>(
        json['exchangeRateCurrency'],
      ),
      indexRateAmount: (decodeExchangeJson<num?>(
        json['indexRateAmount'],
      ))?.toDouble(),
      indexRateCurrency: decodeExchangeJson<String?>(json['indexRateCurrency']),
      payinAmount:
          (decodeExchangeJson<num?>(json['payinAmount']))?.toDouble() ?? 0,
      payinCurrency: decodeExchangeJson<String?>(json['payinCurrency']) ?? '',
      payoutAmount:
          (decodeExchangeJson<num?>(json['payoutAmount']))?.toDouble() ?? 0,
      payoutCurrency: decodeExchangeJson<String?>(json['payoutCurrency']) ?? '',
      orderStatus: decodeExchangeJson<String?>(json['orderStatus']) ?? '',
      payinStatus: decodeExchangeJson<String?>(json['payinStatus']) ?? '',
      payoutStatus: decodeExchangeJson<String?>(json['payoutStatus']) ?? '',
      scheduledPayoutTime: decodeExchangeJson<String?>(
        json['scheduledPayoutTime'],
      ),
      createdAt: decodeExchangeJson<String>(json['createdAt']),
      completedAt: decodeExchangeJson<String?>(json['completedAt']),
      message: decodeExchangeJson<Map<String, dynamic>?>(json['message']),
      sentAt: decodeExchangeJson<String?>(json['sentAt']),
      payinMethod: decodeExchangeJson<String?>(json['payinMethod']) ?? '',
      payoutMethod: decodeExchangeJson<String?>(json['payoutMethod']) ?? '',
      triggerType: decodeExchangeJson<String?>(json['triggerType']),
      confirmationDeadline: decodeExchangeJson<String?>(
        json['confirmationDeadline'],
      ),
      bitcoinTransactionId: decodeExchangeJson<String?>(
        json['bitcoinTransactionId'],
      ),
      lnUrl: decodeExchangeJson<String?>(json['lnUrl']),
      lightningVoucherExpiresAt: decodeExchangeJson<String?>(
        json['lightningVoucherExpiresAt'],
      ),
      isPPBitcoinOutUpdatable: decodeExchangeJson<bool?>(
        json['isPPBitcoinOutUpdatable'],
      ),
      payinAmountChanged: decodeExchangeJson<Map<String, dynamic>?>(
        json['payinAmountChanged'],
      ),
      lightningInvoice: decodeExchangeJson<String?>(json['lightningInvoice']),
      bitcoinAddress: decodeExchangeJson<String?>(json['bitcoinAddress']),
      liquidAddress: decodeExchangeJson<String?>(json['liquidAddress']),
      liquidTransactionId: decodeExchangeJson<String?>(
        json['liquidTransactionId'],
      ),
      lightningAddress: decodeExchangeJson<String?>(json['lightningAddress']),
      beneficiaryName: decodeExchangeJson<String?>(json['beneficiaryName']),
      beneficiaryLabel: decodeExchangeJson<String?>(json['beneficiaryLabel']),
      beneficiaryAccountNumber: decodeExchangeJson<String?>(
        json['beneficiaryAccountNumber'],
      ),
      beneficiaryETransferAddress: decodeExchangeJson<String?>(
        json['beneficiaryETransferAddress'],
      ),
      securityQuestion: decodeExchangeJson<String?>(json['securityQuestion']),
      securityAnswer: decodeExchangeJson<String?>(json['securityAnswer']),
      paymentDescription: decodeExchangeJson<String?>(
        json['paymentDescription'],
      ),
      unbatchedBuyOnchainFees: (decodeExchangeJson<num?>(
        json['unbatchedBuyOnchainFees'],
      ))?.toDouble(),
      bip21URI: decodeExchangeJson<String?>(json['bip21URI']),
      payjoinDetails: decodeExchangeJson<Map<String, dynamic>?>(
        json['payjoinDetails'],
      ),
      referenceNumber: decodeExchangeJson<String?>(json['referenceNumber']),
      originName: decodeExchangeJson<String?>(json['originName']),
      originCedula: decodeExchangeJson<String?>(json['originCedula']),
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
    'bip21URI': bip21URI,
    'payjoinDetails': payjoinDetails,
    'referenceNumber': referenceNumber,
    'originName': originName,
    'originCedula': originCedula,
  };

  /// Whether this order settled through [txId].
  ///
  /// A payjoin replaces the transaction the customer originally built, so the
  /// order's own payin/payout txid and the transaction that actually reached the
  /// chain can differ. Both are checked, otherwise a payjoin stops being linked
  /// back to its order.
  bool matchesTxId(String txId) =>
      bitcoinTransactionId == txId ||
      liquidTransactionId == txId ||
      payjoinDetails?['txid'] == txId;

  Order toEntity({required bool isTestnet}) {
    final orderMsg = message != null && message is Map<String, dynamic>
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
    final confirmationDeadlineDt = confirmationDeadline != null
        ? DateTime.tryParse(confirmationDeadline!)
        : null;
    final createdAtDt = DateTime.parse(createdAt);
    final completedAtDt = completedAt != null
        ? DateTime.tryParse(completedAt!)
        : null;
    final sentAtDt = sentAt != null ? DateTime.tryParse(sentAt!) : null;
    final scheduledPayoutTimeDt = scheduledPayoutTime != null
        ? DateTime.tryParse(scheduledPayoutTime!)
        : null;
    final lightningVoucherExpiresAtDt = lightningVoucherExpiresAt != null
        ? DateTime.tryParse(lightningVoucherExpiresAt!)
        : null;
    final payinAmountChangedObj =
        payinAmountChanged != null && payinAmountChanged is Map<String, dynamic>
        ? PayinAmountChanged(
            requestedAmount:
                decodeExchangeJson<num?>(
                  payinAmountChanged['requestedAmount'],
                )?.toDouble() ??
                0,
            receivedAmount:
                decodeExchangeJson<num?>(
                  payinAmountChanged['receivedAmount'],
                )?.toDouble() ??
                0,
          )
        : null;
    // txid is the only field mapped — see OrderPayjoinDetails for why. It stays
    // null until the exchange has actually seen the payjoin transaction.
    final payjoinDetailsObj = switch (payjoinDetails) {
      final Map<String, dynamic> details => OrderPayjoinDetails(
        txid: decodeExchangeJson<String?>(details['txid']),
      ),
      null => null,
    };

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
          bip21URI: bip21URI,
          payjoinDetails: payjoinDetailsObj,
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
          bip21URI: bip21URI,
          payjoinDetails: payjoinDetailsObj,
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
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          bip21URI: bip21URI,
          payjoinDetails: payjoinDetailsObj,
          isTestnet: isTestnet,
          referenceNumber: referenceNumber,
          originName: originName,
          originCedula: originCedula,
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
          exchangeRateAmount: null,
          exchangeRateCurrency: null,
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
      case OrderType.sellUsdt:
      case OrderType.unknown:
        return Order.generic(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderTypeName: orderType,
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
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
    }
  }
}
