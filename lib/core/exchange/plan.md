# Exchange Feature Plan


We need to add some new endpoints in the datasource:

We will do them one by one.

DATASOURCE FUNCTIONS:

  Future<RecurringBuyOrderSummaryModel> createDCA({
    required CreateDCAOrderPayload params,
  }) async {
    return await _apiClient.requestBBResponse<RecurringBuyOrderSummaryModel>(
      RPCRequest.post(
        servicePath: ServicePath.orderTriggers.enumValue,
        rpcMethod: ServiceMethod.createDCA.enumValue,
        params: params.toParams(),
      ),
      modelParser: (orderSummary) =>
          RecurringBuyOrderSummaryModel.fromJson(orderSummary),
    );
  }


  Future<RecurringBuyOrderSummaryModel> getDCA() async {
    return await _apiClient.requestBBResponse<RecurringBuyOrderSummaryModel>(
      RPCRequest.post(
        servicePath: ServicePath.orderTriggers.enumValue,
        rpcMethod: ServiceMethod.getDCA.enumValue,
      ),
      modelParser: (orderSummary) =>
          RecurringBuyOrderSummaryModel.fromJson(orderSummary),
    );
  }

  Future<LimitOrderModel> addLimitOrder({
    required CreateLimitOrderPayload params,
  }) async {
    try {
      return await _apiClient.requestBBResponse<LimitOrderModel>(
        hasElement: false,
        RPCRequest.post(
          hasElementRootNode: false,
          servicePath: ServicePath.orderTriggers.enumValue,
          rpcMethod: ServiceMethod.addLimitOrder.enumValue,
          params: params.toParams(),
        ),
        modelParser: (orderSummary) => LimitOrderModel.fromJson(orderSummary),
      );
    } catch (e, s) {
      rethrow;
    }
  }

  Future<LimitOrderModel> cancelLimitOrder({
    required String orderId,
  }) async {
    return await _apiClient.requestBBResponse<LimitOrderModel>(
      hasElement: false,
      RPCRequest.post(
        hasElementRootNode: false,
        servicePath: ServicePath.orderTriggers.enumValue,
        rpcMethod: ServiceMethod.cancelLimitOrder.enumValue,
        params: {
          'limitOrderId': orderId,
        },
      ),
      modelParser: (orderSummary) => LimitOrderModel.fromJson(orderSummary),
    );
  }

  Future<ListResponse<LimitOrderModel>> listLimitOrders(
    ListRequest params,
  ) async {
    return await _apiClient.requestBBListResponse<LimitOrderModel>(
      RPCRequest.post(
        servicePath: ServicePath.orderTriggers.enumValue,
        rpcMethod: ServiceMethod.listLimitOrders.enumValue,
        params: params.toParams(),
      ),
      modelParser: (orderSummary) => LimitOrderModel.fromJson(orderSummary),
    );
  }

  Future<ListResponse<LimitOrderModel>> cancelAllLimitOrders() async {
    return await _apiClient.requestBBListResponse<LimitOrderModel>(
      RPCRequest.post(
        servicePath: ServicePath.orderTriggers.enumValue,
        rpcMethod: ServiceMethod.cancelAllLimitOrders.enumValue,
      ),
      modelParser: (orderSummary) => LimitOrderModel.fromJson(orderSummary),
    );
  }

  Future<LimitOrderModel> getLimitOrder({
    required String orderId,
  }) async {
    return await _apiClient.requestBBResponse<LimitOrderModel>(
      hasElement: false,
      RPCRequest.post(
          hasElementRootNode: false,
          servicePath: ServicePath.orderTriggers.enumValue,
          rpcMethod: ServiceMethod.getLimitOrder.enumValue,
          params: {
            'limitOrderId': orderId,
          }),
      modelParser: (orderSummary) => LimitOrderModel.fromJson(orderSummary),
    );
  }



  Future<OrderSummaryModel> cancelOrderSummary({
    required String orderId,
  }) async {
    return await _apiClient.requestBBResponse<OrderSummaryModel>(
      hasElement: false,
      RPCRequest.post(
        hasElementRootNode: false,
        servicePath: ServicePath.orders.enumValue,
        rpcMethod: ServiceMethod.cancelOrderSummary.enumValue,
        params: {
          'orderId': orderId,
        },
      ),
      modelParser: (orderSummary) => OrderSummaryModel.fromJson(orderSummary),
    );
  }

  Future<ListResponse<LegacyOrderModel>> listLegacyOrders(
    ListRequest params,
  ) async {
    return await _apiClient.requestBBListResponse<LegacyOrderModel>(
      RPCRequest.post(
        servicePath: ServicePath.orders.enumValue,
        rpcMethod: ServiceMethod.listV2Orders.enumValue,
        params: params.toParams(),
      ),
      modelParser: (orderSummary) => LegacyOrderModel.fromJson(orderSummary),
    );
  }

  Future<BuyLimitsModel> getBuyLimits() async {
    final response = await _apiClient.requestBBResponse<BuyLimitsModel>(
      RPCRequest.post(
        servicePath: ServicePath.orders.enumValue,
        rpcMethod: ServiceMethod.getBuyLimits.enumValue,
      ),
      hasElement: false,
      modelParser: (json) => BuyLimitsModel.fromJson(json),
    );

    return response;
  }

  Future<SellLimitsModel> getSellLimits() async {
    final response = await _apiClient.requestBBResponse<SellLimitsModel>(
      RPCRequest.post(
        servicePath: ServicePath.orders.enumValue,
        rpcMethod: ServiceMethod.getSellLimits.enumValue,
      ),
      hasElement: false,
      modelParser: (json) => SellLimitsModel.fromJson(json),
    );

    return response;
  }

Future<RateModel> getUserRate({
    required RateCurrency fromCurrency,
    required RateCurrency toCurrency,
  }) async {
    final response = await _apiClient.requestBBResponse<RateModel>(
      RPCRequest.post(
        servicePath: ServicePath.pricer.enumValue,
        rpcMethod: ServiceMethod.getUserRate.enumValue,
        params: {
          'element': {
            'fromCurrency': fromCurrency.enumValue,
            'toCurrency': toCurrency.enumValue,
          },
        },
      ),
      modelParser: (json) => RateModel.fromJson(json),
    );

    return response;
  }

  Future saveUserPreference(UserPreferencePayload params) async {
    final response = await _apiClient.requestDynamicResponse(
      RPCRequest.post(
        servicePath: ServicePath.user.enumValue,
        rpcMethod: ServiceMethod.saveUserPreferences.enumValue,
        params: {
          'userPreferences': params.toMap(),
        },
      ),
    );
    return response;
  }
 Future<ReferralCodeModel> createReferralCode(String code) async {
    final response = await _apiClient.requestDynamicResponse(
      RPCRequest.post(
        servicePath: ServicePath.user.enumValue,
        rpcMethod: ServiceMethod.createReferralCode.enumValue,
        params: {'code': code},
      ),
    );
    return ReferralCodeModel.fromJson(response.data['result']['element']);
  }

  Future<ListResponse<ReferralCodeModel>> listReferralCodes({
    Map<String, dynamic>? paginator,
    Map<String, dynamic>? sortBy,
    String? status,
  }) async {
    final response = await _apiClient.requestBBListResponse(
      RPCRequest.post(
        servicePath: ServicePath.user.enumValue,
        rpcMethod: ServiceMethod.listReferralCodes.enumValue,
      ),
      modelParser: (json, [extraData]) {
        final model = ReferralCodeModel.fromJson(json);

        return model;
      },
    );

    return response;
  }
  Future<bool> consentToScamWarning() async {
    final response = await _apiClient.requestDynamicResponse<bool>(
      RPCRequest.post(
        servicePath: ServicePath.user.enumValue,
        rpcMethod: ServiceMethod.registerResponsibilityConsent.enumValue,
      ),
    );
    if (response.data['result']['success'] == true) {
      return true;
    }
    return false;
  }

REFERENCE STRINGS:
For rpcMethod; use these strings from the enums provided when implemented in the datasource:

  saveUserPreferences('saveUserPreferences'),
   getUserRate('getUserRate'),
    listCurrencies('listCurrencies'),
  listOrderTypes('listOrderTypes'),
  listPaymentProcessorTypes('listPaymentProcessorTypes'),
  listPaymentProcessorDataTypes('listPaymentProcessorDataTypes'),

  // orders
  getMyBestOption('getMyBestOption'),
  getUserPaymentProcessorCode('getUserPaymentProcessorCode'),
  createMyOrder('createMyOrder'),
  confirmMyOrder('confirmMyOrder'),
  refreshMyOrder('refreshMyOrder'),
  dequeueAndPay('dequeueAndPay'),
  updatePPBitcoinOut('updatePPBitcoinOut'),
  getMyOrder('getMyOrder'),
  listMyOrders('listMyOrders'),
  validateBolt11('validateBolt11'),
  validateLNPayAddress('validateLNPayAddress'),
  validateBitcoinAddress('validateBitcoinAddress'),
  validateLiquidAddress('validateLiquidAddress'),
  getOrderSummary('getOrderSummary'),
  listOrderSummaries('listOrderSummaries'),
  createOrderSummary('createOrderSummary'), //createMyOrder
  refreshOrderSummary('refreshOrderSummary'), //refreshMyOrder
  confirmOrderSummary('confirmOrderSummary'), //confirmMyOrder
  cancelOrderSummary('cancelOrderSummary'), //cancelMyOrder
  unbatchAndExpressOrder('unbatchAndExpressOrder'), //dequeueAndPay
  updateBitcoinPayoutMethod('updateBitcoinPayoutMethod'), //updatePPBitcoinOut
  getBuyLimits('getBuyLimits'),
  getSellLimits('getSellLimits'),

  listV2Orders('listV2Orders'),
  createDCA('createDCA'),
  addLimitOrder('addLimitOrder'),
  cancelLimitOrder('cancelLimitOrder'),
  listLimitOrders('listLimitOrders'),
  getLimitOrder('getLimitOrder'),
  cancelAllLimitOrders('cancelAllLimitOrders'),
  getDCA('getDCA'),

  // referrals
  createReferralCode('createReferralCode'),
  listReferralCodes('listReferralCodes'),

  // recipients
  listMyRecipients('listMyRecipients'),
  createMyRecipient('createMyRecipient'),
  updateMyRecipient('updateMyRecipient'),
  listApayloBillers('listAplBillers'),


------------------
MODELS:

class LimitOrderModel extends LimitOrder {
  const LimitOrderModel({
    required super.limitOrderId,
    required super.limitOrderNumber,
    required super.userId,
    required super.userNbr,
    required super.fiatAmount,
    required super.currencyCode,
    required super.limitPrice,
    required super.estimatedBtcAmount,
    required super.status,
    required super.createdAt,
    required super.expiresAt,
    required super.lastCheckedAt,
    required super.executedAt,
    required super.cancelledAt,
    required super.executedOrderId,
  });

  factory LimitOrderModel.fromJson(Map<String, dynamic> json) {
    try {
      final cancelledAt = json['cancelledAt'] as String?;
      final executedAt = json['executedAt'] as String?;
      final executedOrderId = json['executedOrderId'] as String?;

      return LimitOrderModel(
        limitOrderId: json['limitOrderId'] as String,
        limitOrderNumber: json['limitOrderNbr'] as String,
        userId: json['userId'] as String,
        userNbr: json['userNbr'] as int,
        fiatAmount: json['fiatAmount'] as String,
        currencyCode: json['currencyCode'] as String,
        limitPrice: json['limitPrice'] as String,
        estimatedBtcAmount: json['estimatedBtcAmount'] as String,
        status:
            stringToEnum(json['status'] as String, LimitOrderStatus.values)!,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        lastCheckedAt: DateTime.parse(json['lastCheckedAt'] as String),
        executedAt: executedAt != null ? DateTime.parse(executedAt) : null,
        cancelledAt: cancelledAt != null ? DateTime.parse(cancelledAt) : null,
        executedOrderId: executedOrderId,
      );
    } catch (e) {
      rethrow;
    }
  }
}


class RecurringBuyOrderSummaryModel extends RecurringBuyOrderSummary {
  RecurringBuyOrderSummaryModel({
    required super.amount,
    required super.currencyCode,
    required super.recurringFrequency,
    required super.recipientType,
    required super.address,
    required super.createdAt,
    required super.nextRunAt,
  });

  factory RecurringBuyOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    return RecurringBuyOrderSummaryModel(
      amount: json['amountStr'] as String,
      currencyCode: json['currencyCode'] as String,
      recurringFrequency: stringToEnum<DCARecurringFrequencyType>(
        json['recurringFrequency'] as String,
        DCARecurringFrequencyType.values,
      )!,
      recipientType: stringToEnum<RecipientType>(
        json['recipientType'] as String,
        RecipientType.values,
      )!,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      nextRunAt: DateTime.parse(json['nextRunAt'] as String),
    );
  }
}

class ReferralCodeModel extends ReferralCode {
  const ReferralCodeModel({
    required super.code,
    required super.isDefault,
    required super.createdAt,
  });

  factory ReferralCodeModel.fromJson(Map<String, dynamic> json) {
    return ReferralCodeModel(
      // id: json['id'],
      code: json['code'],
      isDefault: json['isDefault'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

import 'package:bb_flutter_core/repo/entity/recipient/recipient.dart';
import 'package:bb_flutter_core/utils/enum_helper.dart';

class RecipientModel extends Recipient {
  const RecipientModel({
    super.recipientId,
    super.userId,
    super.userNbr,
    super.isOwner,
    super.isArchived,
    super.createdAt,
    super.updatedAt,
    super.label,
    super.paymentProcessors,
    super.recipientType,
    super.firstname,
    super.lastname,
    super.name,
    super.iban,
    super.email,
    super.securityQuestion,
    super.securityAnswer,
    super.institutionNumber,
    super.transitNumber,
    super.accountNumber,
    super.billerPayeeCode,
    super.billerPayeeName,
    super.billerPayeeAccountNumber,
    super.address,
    super.isDefault,
    // Mexican beneficiary fields
    super.clabe,
    super.phone,
    super.debitCard,
    super.institutionCode,
    super.isCorporate,
    super.corporateName,
  });

  factory RecipientModel.fromJson(Map<String, dynamic> json) {
    try {
      return RecipientModel(
        recipientId: json['recipientId'],
        userId: json['userId'],
        userNbr: json['userNbr'],
        isOwner: json['isOwner'],
        isArchived: json['isArchived'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        label: json['label'],
        paymentProcessors: (json['paymentProcessors'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        recipientType: stringToEnum<RecipientType>(
          json['recipientType'],
          RecipientType.values,
        ),
        firstname: json['firstname'],
        lastname: json['lastname'],
        name: json['name'],
        iban: json['iban'],
        email: json['email'],
        securityQuestion: json['securityQuestion'],
        securityAnswer: json['securityAnswer'],
        institutionNumber: json['institutionNumber'],
        transitNumber: json['transitNumber'],
        accountNumber: json['accountNumber'],
        billerPayeeCode: json['payeeCode'],
        billerPayeeName: json['payeeName'],
        billerPayeeAccountNumber: json['payeeAccountNumber'],
        address: json['address'],
        isDefault: json['isDefault'],
        clabe: json['clabe'],
        phone: json['phone'],
        debitCard: json['debitcard'],
        institutionCode: json['institutionCode'],
        isCorporate: json['isCorporate'],
        corporateName: json['corporateName'],
      );
    } catch (e) {
      throw 'Error Occured: Please contact support';
    }
  }
}

import 'package:bb_flutter_core/repo/entity/order/limits.dart';
import 'package:bb_flutter_core/repo/entity/pricer/rate.dart';
import 'package:bb_flutter_core/repo/entity/recipient/pp.dart';
import 'package:bb_flutter_core/utils/enum_helper.dart';

class TransactionLimitModel extends TransactionLimit {
  const TransactionLimitModel({
    required super.currencyCode,
    required super.amount,
    required super.frequency,
    required super.operator,
    super.timePeriod,
  });

  factory TransactionLimitModel.fromJson(Map<String, dynamic> json) {
    return TransactionLimitModel(
      currencyCode: stringToEnum<RateCurrency>(
          json['currencyCode']?.toString(), RateCurrency.values)!,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      frequency: LimitFrequency.fromJson(json['frequency']?.toString() ?? 'TX'),
      operator: LimitOperator.fromJson(json['operator']?.toString() ?? 'EQUAL'),
      timePeriod: json['timePeriod'] as int?,
    );
  }
}

class PaymentOptionModel extends PaymentOption {
  const PaymentOptionModel({
    required super.paymentOptionCode,
    required super.timeoutMinutes,
    required super.inPaymentProcessorCode,
    required super.outPaymentProcessorCode,
    // required super.upperLimits,
    // required super.lowerLimits,
    required super.txLimits,
  });

  factory PaymentOptionModel.fromJson(Map<String, dynamic> json) {
    return PaymentOptionModel(
      paymentOptionCode: PaymentOptionCode.fromJson(
          json['paymentOptionCode']?.toString() ?? ''),
      timeoutMinutes: json['timeoutMinutes'] as int? ?? 0,
      inPaymentProcessorCode: stringToEnum<InPaymentProcessor>(
          json['inPaymentProcessorCode']?.toString(),
          InPaymentProcessor.values)!,
      outPaymentProcessorCode: stringToEnum<OutPaymentProcessor>(
          json['outPaymentProcessorCode']?.toString(),
          OutPaymentProcessor.values)!,
      // upperLimits: (json['upperLimits'] as List<dynamic>?)
      //         ?.map((e) =>
      //             TransactionLimitModel.fromJson(e as Map<String, dynamic>))
      //         .toList() ??
      //     [],
      // lowerLimits: (json['lowerLimits'] as List<dynamic>?)
      //         ?.map((e) =>
      //             TransactionLimitModel.fromJson(e as Map<String, dynamic>))
      //         .toList() ??
      //     [],
      txLimits: (json['txLimits'] as List<dynamic>?)
              ?.map((e) =>
                  TransactionLimitModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PaymentProcessorLimitsModel extends PaymentProcessorLimits {
  const PaymentProcessorLimitsModel({
    required super.isPPAvailable,
    required super.paymentOption,
  });

  factory PaymentProcessorLimitsModel.fromJson(Map<String, dynamic> json) {
    return PaymentProcessorLimitsModel(
      isPPAvailable: json['isPPAvailable'] as bool? ?? false,
      paymentOption: (json['paymentOption'] as List<dynamic>?)
              ?.map(
                  (e) => PaymentOptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BuyLimitsModel extends BuyLimits {
  const BuyLimitsModel({
    required super.onchain,
    required super.lightning,
    required super.liquid,
    required super.lnurlWithdraw,
    required super.lnurlPay,
  });

  factory BuyLimitsModel.fromJson(Map<String, dynamic> jsonn) {
    try {
      final json = jsonn['limits'];
      return BuyLimitsModel(
        onchain: PaymentProcessorLimitsModel.fromJson(
          json['bitcoin'] as Map<String, dynamic>? ?? {},
        ),
        lightning: PaymentProcessorLimitsModel.fromJson(
          json['lightning'] as Map<String, dynamic>? ?? {},
        ),
        liquid: PaymentProcessorLimitsModel.fromJson(
          json['liquid'] as Map<String, dynamic>? ?? {},
        ),
        lnurlWithdraw: PaymentProcessorLimitsModel.fromJson(
          json['lnurlWithdraw'] as Map<String, dynamic>? ?? {},
        ),
        lnurlPay: PaymentProcessorLimitsModel.fromJson(
          json['lnurlPay'] as Map<String, dynamic>? ?? {},
        ),
      );
    } catch (e, s) {
      rethrow;
    }
  }
}

class SellLimitsModel extends SellLimits {
  const SellLimitsModel({
    required super.onchain,
    required super.lightning,
    required super.liquid,
  });

  factory SellLimitsModel.fromJson(Map<String, dynamic> json) {
    return SellLimitsModel(
      onchain: PaymentProcessorLimitsModel.fromJson(
        json['onchain'] as Map<String, dynamic>? ?? {},
      ),
      lightning: PaymentProcessorLimitsModel.fromJson(
        json['lightning'] as Map<String, dynamic>? ?? {},
      ),
      liquid: PaymentProcessorLimitsModel.fromJson(
        json['liquid'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

import 'package:bb_flutter_core/_repo/entity/order/order_summary.dart';
import 'package:bb_flutter_core/_repo/entity/pricer/rate.dart';
import 'package:bb_flutter_core/_repo/entity/recipient/recipient.dart';
import 'package:bb_flutter_core/bb_flutter_core.dart';
import 'package:bb_flutter_core/utils/enum_helper.dart';

class UserOrderPayload {
  final String? userId;
  final int? userNumber;
  final String? userIdTransactionIn;
  final int? userNumberTransactionIn;
  final String? userIdTransactionOut;
  final int? userNumberTransactionOut;
  final String? note;
  final double amount;
  final bool isInAmountFixed;
  final InPaymentProcessor inPaymentProcessor;
  final OutPaymentProcessor outPaymentProcessor;
  final dynamic outTransactionData;
  final dynamic inTransactionData;
  final String? outRecipientId;

  UserOrderPayload({
    this.userId,
    this.userNumber,
    this.userIdTransactionIn,
    this.userNumberTransactionIn,
    this.userIdTransactionOut,
    this.userNumberTransactionOut,
    this.note,
    required this.amount,
    required this.isInAmountFixed,
    required this.inPaymentProcessor,
    required this.outPaymentProcessor,
    this.outTransactionData,
    this.inTransactionData,
    this.outRecipientId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    data['userId'] = userId;
    data['userNumber'] = userNumber;
    data['userIdTransactionIn'] = userIdTransactionIn;
    data['userNumberTransactionIn'] = userNumberTransactionIn;
    data['userNumberTransactionIn'] = userNumberTransactionIn;
    data['userIdTransactionOut'] = userIdTransactionOut;
    data['note'] = note;
    data['amount'] = amount;
    data['isInAmountFixed'] = isInAmountFixed;
    data['inPaymentProcessor'] = inPaymentProcessor.enumValue;
    data['outPaymentProcessor'] = outPaymentProcessor.enumValue;
    data['outTransactionData'] = outTransactionData;
    data['inTransactionData'] = inTransactionData;
    data['outRecipientId'] = outRecipientId;

    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class ListRatePayload {
  final RateCurrency fromCurrency;
  final RateCurrency toCurrency;
  final DateTime? fromDate;
  final DateTime? toDate;
  final RateTimelineInterval? interval;

  ListRatePayload({
    required this.fromCurrency,
    required this.toCurrency,
    this.fromDate,
    this.toDate,
    this.interval,
  });

  String get _fromDate {
    //should be one yer ago by default
    if (fromDate != null) return fromDate!.millisecondsSinceEpoch.toString();
    return DateTime.now()
        .subtract(const Duration(days: 365))
        .millisecondsSinceEpoch
        .toString();
  }

  String get _toDate {
    if (fromDate != null) return toDate!.millisecondsSinceEpoch.toString();
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['fromCurrency'] = fromCurrency.enumValue;
    data['toCurrency'] = toCurrency.enumValue;
    data['fromDate'] = _fromDate;
    data['toDate'] = _toDate;
    data['interval'] =
        interval?.enumValue ?? RateTimelineInterval.day.enumValue;

    data.removeWhere((key, value) => value == null);
    return {'element': data};
  }
}

class OrdersPayload extends IFilterParams {
  final Map<String, dynamic>? filters;

  OrdersPayload({
    this.filters,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    if (filters != null) {
      data['filters'] = filters;
    }

    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class UpdatePPBitcoinOutPayload implements AnyToParams {
  final String orderId;
  final OutPaymentProcessor ppOut;
  final String? bolt11Address;
  final String? recipientId;

  UpdatePPBitcoinOutPayload.outBitcoinAddress({
    required this.orderId,
    required this.ppOut,
    required this.recipientId,
  }) : bolt11Address = null;

  UpdatePPBitcoinOutPayload.outLightningAddress({
    required this.orderId,
    required this.ppOut,
    required this.recipientId,
  }) : bolt11Address = null;

  UpdatePPBitcoinOutPayload.outLiquidAddress({
    required this.orderId,
    required this.ppOut,
    required this.recipientId,
  }) : bolt11Address = null;

  UpdatePPBitcoinOutPayload.outBolt11Address({
    required this.orderId,
    required this.ppOut,
    required this.bolt11Address,
  }) : recipientId = null;

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};
    data['orderId'] = orderId;
    data['paymentProcessorCode'] = ppOut.enumValue;
    data['recipientId'] = recipientId;
    data['bolt11'] = bolt11Address;

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

enum BuyOrderNetwork with EnumHelper<BuyOrderNetwork> {
  bitcoin('bitcoin'),
  lightning('lightning'),
  liquid('liquid');

  final String _path;
  const BuyOrderNetwork(this._path);

  @override
  String get enumValue => _path;
}

class UpdateBitcoinPayoutMethodPayload implements AnyToParams {
  final String orderId;
  final BuyOrderNetwork network;
  final String? invoice;
  final String? address;
  final bool isOwner;
  final String? ownerFullName;

  UpdateBitcoinPayoutMethodPayload.outBitcoinAddress({
    required this.orderId,
    required this.address,
    required this.isOwner,
    this.ownerFullName,
  })  : network = BuyOrderNetwork.bitcoin,
        invoice = null;

  UpdateBitcoinPayoutMethodPayload.outLightningAddress({
    required this.orderId,
    required this.address,
    required this.isOwner,
    this.ownerFullName,
  })  : network = BuyOrderNetwork.lightning,
        invoice = null;

  UpdateBitcoinPayoutMethodPayload.outLiquidAddress({
    required this.orderId,
    required this.address,
    required this.isOwner,
    this.ownerFullName,
  })  : network = BuyOrderNetwork.liquid,
        invoice = null;

  UpdateBitcoinPayoutMethodPayload.outLightningInvoice({
    required this.orderId,
    required this.invoice,
  })  : network = BuyOrderNetwork.lightning,
        isOwner = true,
        address = null,
        ownerFullName = null;

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};
    data['orderId'] = orderId;
    data['network'] = network.enumValue;
    data['address'] = address;
    data['invoice'] = invoice;
    data['isOwner'] = isOwner;
    data['ownerFullName'] = ownerFullName;

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

//  "amountStr": "10.22",
// "currencyCode": "MXN",
// "recurringFrequency": "HOUR",
// "recipientType":"OUT_BITCOIN_ADDRESS"

class CreateDCAOrderPayload implements AnyToParams {
  final String amountStr;
  final String currencyCode;
  final DCARecurringFrequencyType recurringFrequency;
  final RecipientType recipientType;

  CreateDCAOrderPayload({
    required this.amountStr,
    required this.currencyCode,
    required this.recurringFrequency,
    required this.recipientType,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};
    data['amountStr'] = amountStr;
    data['currencyCode'] = currencyCode;
    data['recurringFrequency'] = recurringFrequency.enumValue;
    data['recipientType'] = recipientType.enumValue;

    data.removeWhere((key, value) => value == null);

    return {
      'element': data,
    };
  }
}
import 'package:bb_flutter_core/_repo/entity/recipient/recipient.dart';
import 'package:bb_flutter_core/bb_flutter_core.dart';

sealed class RecipientDetailsType implements AnyToParams {}

class RecipientDetailsCjPayee extends RecipientDetailsType {
  String iban;
  String? firstName;
  String? lastName;
  bool? isCorporate;
  String? corporateName;

  RecipientDetailsCjPayee({
    required this.firstName,
    required this.lastName,
    required this.iban,
    this.isCorporate = false,
    this.corporateName,
  });

  RecipientDetailsCjPayee.individual({
    required this.firstName,
    required this.lastName,
    required this.iban,
  }) : isCorporate = false;

  RecipientDetailsCjPayee.corporate({
    required this.corporateName,
    required this.iban,
  }) : isCorporate = true;

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['firstname'] = firstName;
    data['lastname'] = lastName;
    data['isCorporate'] = isCorporate;
    data['corporateName'] = corporateName;
    data['iban'] = iban;
    return data;
  }
}

class RecipientDetailsOutInteracEmail extends RecipientDetailsType {
  String firstName;
  String? lastName;
  String email;
  String securityQuestion;
  String securityAnswer;

  RecipientDetailsOutInteracEmail({
    required this.firstName,
    this.lastName,
    required this.email,
    required this.securityQuestion,
    required this.securityAnswer,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['firstname'] = firstName;
    data['lastname'] = lastName;
    data['email'] = email;
    data['securityQuestion'] = securityQuestion;
    data['securityAnswer'] = securityAnswer;
    return data;
  }
}

class RecipientDetailsOutBankAccountEftCa extends RecipientDetailsType {
  String institutionNumber;
  String transitNumber;
  String accountNumber;
  String firstName;
  String lastName;
  String? defaultComment;

  RecipientDetailsOutBankAccountEftCa({
    required this.institutionNumber,
    required this.transitNumber,
    required this.accountNumber,
    required this.firstName,
    required this.lastName,
    this.defaultComment,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['institutionNumber'] = institutionNumber;
    data['transitNumber'] = transitNumber;
    data['accountNumber'] = accountNumber;
    data['firstname'] = firstName;
    data['lastname'] = lastName;
    data['defaultComment'] = defaultComment;

    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class RecipientDetailsOutBillPaymentCa extends RecipientDetailsType {
  String payeeName;
  String payeeCode;
  String payeeAccountNumber;

  RecipientDetailsOutBillPaymentCa({
    required this.payeeCode,
    required this.payeeName,
    required this.payeeAccountNumber,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['payeeName'] = payeeName;
    data['payeeCode'] = payeeCode;
    data['payeeAccountNumber'] = payeeAccountNumber;

    return data;
  }
}

class RecipientDetailsOutLightningAddress extends RecipientDetailsType {
  String lightningAddress;
  String? name; //required if not isOwner
  RecipientDetailsOutLightningAddress({
    required this.lightningAddress,
    this.name,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['address'] = lightningAddress;
    data['name'] = name;

    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class RecipientDetailsOutBitcoinAddress extends RecipientDetailsType {
  String bitcoinAddress;
  String? name; //required if not isOwner

  RecipientDetailsOutBitcoinAddress({
    required this.bitcoinAddress,
    this.name,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['address'] = bitcoinAddress;
    data['name'] = name;

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

class RecipientDetailsOutLiquidAddress extends RecipientDetailsType {
  String liquidAddress;
  String? name; //required if not isOwner

  RecipientDetailsOutLiquidAddress({
    required this.liquidAddress,
    this.name,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['address'] = liquidAddress;
    data['name'] = name;

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

class RecipientDetailsOutBitsoClabe extends RecipientDetailsType {
  String firstName;
  String lastName;
  String clabe;

  RecipientDetailsOutBitsoClabe({
    required this.firstName,
    required this.lastName,
    required this.clabe,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['firstname'] = firstName;
    data['lastname'] = lastName;
    data['clabe'] = clabe;
    return data;
  }
}

class RecipientDetailsOutBitsoPhone extends RecipientDetailsType {
  String firstName;
  String lastName;
  String institutionCode;
  String phone;

  RecipientDetailsOutBitsoPhone({
    required this.firstName,
    required this.lastName,
    required this.institutionCode,
    required this.phone,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['firstname'] = firstName;
    data['lastname'] = lastName;
    data['institutionCode'] = institutionCode;
    data['phone'] = phone;
    return data;
  }
}

class RecipientDetailsOutBitsoCard extends RecipientDetailsType {
  String firstName;
  String lastName;
  String institutionCode;
  String debitCard;

  RecipientDetailsOutBitsoCard({
    required this.firstName,
    required this.lastName,
    required this.institutionCode,
    required this.debitCard,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    data['firstname'] = firstName;
    data['lastname'] = lastName;
    data['institutionCode'] = institutionCode;
    data['debitcard'] = debitCard;
    return data;
  }
}

class CreateMyRecipientPayload implements AnyToParams {
  RecipientType recipientType;
  String? label;
  bool? isDefault;
  RecipientDetailsType recipientDetails;
  bool isOwner;

  CreateMyRecipientPayload.outBitcoinAddress({
    required RecipientDetailsOutBitcoinAddress this.recipientDetails,
    required this.isOwner,
    this.isDefault = false,
    this.label,
  }) : recipientType = RecipientType.outBitcoinAddress;

  CreateMyRecipientPayload.outLightningAddress({
    required RecipientDetailsOutLightningAddress this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outLightningAddress;

  CreateMyRecipientPayload.outLiquidAddress({
    required RecipientDetailsOutLiquidAddress this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outLiquidAddress;

  CreateMyRecipientPayload.cjPayee({
    required RecipientDetailsCjPayee this.recipientDetails,
    required this.isOwner,
    this.label,
  }) : recipientType = RecipientType.cjPayee;

  CreateMyRecipientPayload.cjPayeeIndividual({
    required String firstName,
    required String lastName,
    required String iban,
    required this.isOwner,
    this.label,
  })  : recipientType = RecipientType.cjPayee,
        recipientDetails = RecipientDetailsCjPayee.individual(
          firstName: firstName,
          lastName: lastName,
          iban: iban,
        );

  CreateMyRecipientPayload.cjPayeeCoporate({
    required String corporateName,
    required String iban,
    this.label,
  })  : recipientType = RecipientType.cjPayee,
        isOwner = false,
        recipientDetails = RecipientDetailsCjPayee.corporate(
          corporateName: corporateName,
          iban: iban,
        );

  CreateMyRecipientPayload.outInteracEmail({
    required RecipientDetailsOutInteracEmail this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outInteracEmail;

  CreateMyRecipientPayload.outBankAccountEftCa({
    required RecipientDetailsOutBankAccountEftCa this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outBankAccountEftCa;

  CreateMyRecipientPayload.outBillPaymentCa({
    required RecipientDetailsOutBillPaymentCa this.recipientDetails,
    this.isOwner = false,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outBillPaymentCa;

  CreateMyRecipientPayload.outBitsoClabe({
    required RecipientDetailsOutBitsoClabe this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outBitsoClabe;

  CreateMyRecipientPayload.outBitsoPhone({
    required RecipientDetailsOutBitsoPhone this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outBitsoPhone;

  CreateMyRecipientPayload.outBitsoCard({
    required RecipientDetailsOutBitsoCard this.recipientDetails,
    required this.isOwner,
    this.isDefault,
    this.label,
  }) : recipientType = RecipientType.outBitsoCard;

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {
      'element': {},
    };

    data['element']['recipientType'] = recipientType.enumValue;
    (data['element'] as Map).addAll(recipientDetails.toParams());
    if (label != null) if (label!.isNotEmpty) data['element']['label'] = label;
    if (isDefault != null) data['element']['isDefault'] = isDefault;
    data['element']['isOwner'] = isOwner;

    return data;
  }
}

class RecipientsPayload extends IFilterParams {
  ListMyRecipientsFilters? filters;

  RecipientsPayload({
    this.filters,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};

    if (filters != null) data['filters'] = filters!.toParams();

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

class ListMyRecipientsFilters implements AnyToParams {
  String? currencyCode;
  List<RecipientType>? recipientTypes;
  bool? isDefault;

  ListMyRecipientsFilters({
    this.currencyCode,
    this.recipientTypes,
    this.isDefault,
  });

  @override
  Map<String, dynamic> toParams() {
    final Map<String, dynamic> data = {};
    data['recipientType'] = recipientTypes?.map((e) => e.enumValue).toList();
    data['currency'] = currencyCode;
    data['isDefault'] = isDefault;
    {
      data.removeWhere((key, value) => value == null);
      return data;
    }
  }
}
class UserPreferencePayload {
  final String? laguage;
  final String? currencyCode;
  final String? dcaEnabled;
  final String? autoBuyEnabled;

  UserPreferencePayload({
    required this.laguage,
    required this.currencyCode,
    this.dcaEnabled,
    this.autoBuyEnabled,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {};

    data['LANGUAGE'] = laguage;
    data['DEFAULT_FIAT_CURRENCY_CODE'] = currencyCode;
    if (dcaEnabled != null) {
      data['DCA_ENABLED'] = dcaEnabled;
    }
    if (autoBuyEnabled != null) {
      data['AUTO_BUY_ENABLED'] = autoBuyEnabled;
    }

    data.removeWhere((key, value) => value == null);
    return data;
  }
}
