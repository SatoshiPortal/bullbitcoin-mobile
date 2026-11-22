import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/orders/order_limits.dart';
import 'package:bbx_api/src/orders/order_stats.dart';
import 'package:bbx_api/src/orders/order_summary.dart';

OrderLimits parseOrderLimits(Map<String, dynamic> json) {
  final limits = read<Map<String, dynamic>?>(json['limits'], 'limits');
  return OrderLimits(
    minimum: read<num?>(json['min'], 'min'),
    maximum: read<num?>(json['max'], 'max'),
    currencyLimits: limits == null
        ? const []
        : [
            for (final MapEntry(:key, :value) in limits.entries)
              OrderCurrencyLimits(
                currencyCode: key,
                values: [
                  for (final limit in read<List<dynamic>>(value, 'limits'))
                    read<num>(limit, 'limits'),
                ],
              ),
          ],
  );
}

OrderStatsReport parseOrderStatsReport(Map<String, dynamic> json) {
  final asOf = DateTime.tryParse(read<String>(json['asOf'], 'asOf'));
  if (asOf == null) throw const BbxFormatException('invalid asOf');
  return OrderStatsReport(
    orderStats: parseOrderStats(
      read<Map<String, dynamic>>(json['orderStats'], 'orderStats'),
    ),
    billerStats: parseBillerStats(
      read<Map<String, dynamic>>(json['billerStats'], 'billerStats'),
    ),
    asOf: asOf,
  );
}

OrderStats parseOrderStats(Map<String, dynamic> json) {
  List<CurrencyAmount> amounts(String field) =>
      readList(json[field], field, parseCurrencyAmount);
  return OrderStats(
    bitcoinBuyVolume: amounts('bitcoinBuyVolume'),
    bitcoinBuyTradeCount: amounts('bitcoinBuyTradeCount'),
    averageBitcoinBuyPrice: amounts('averageBitcoinBuyPrice'),
    bitcoinSellVolume: amounts('bitcoinSellVolume'),
    bitcoinSellTradeCount: amounts('bitcoinSellTradeCount'),
    averageBitcoinSellPrice: amounts('averageBitcoinSellPrice'),
    totalBitcoinTradingVolume: amounts('totalBitcoinTradingVolume'),
    buySellRatio: read<String?>(json['buySellRatio'], 'buySellRatio') ?? '0:0',
  );
}

CurrencyAmount parseCurrencyAmount(Map<String, dynamic> json) => CurrencyAmount(
  currency: read<String>(json['currency'], 'currency'),
  value: read<num>(json['value'], 'value').toDouble(),
);

BillerStats parseBillerStats(Map<String, dynamic> json) => BillerStats(
  currency: read<String?>(json['currency'], 'currency') ?? '',
  stats: readList(json['stats'], 'stats', parseBillerStat),
);

BillerStat parseBillerStat(Map<String, dynamic> json) => BillerStat(
  billerName: read<String?>(json['billerName'], 'billerName') ?? '',
  billerCode: read<String?>(json['billerCode'], 'billerCode') ?? '',
  totalAmount:
      read<num?>(json['totalAmount'], 'totalAmount')?.toDouble() ?? 0.0,
  tradeCount: read<int?>(json['tradeCount'], 'tradeCount') ?? 0,
);

OrderSummary parseOrderSummary(Map<String, dynamic> json) {
  String? string(String field) => read<String?>(json[field], field);
  double? number(String field) => read<num?>(json[field], field)?.toDouble();
  Map<String, dynamic>? object(String field) =>
      read<Map<String, dynamic>?>(json[field], field);

  final message = object('message');
  final payinAmountChanged = object('payinAmountChanged');
  final payjoinDetails = object('payjoinDetails');
  return OrderSummary(
    orderId: read<String>(json['orderId'], 'orderId'),
    orderType: read<String>(json['orderType'], 'orderType'),
    orderSubtype: string('orderSubtype'),
    orderNumber: read<int>(json['orderNumber'], 'orderNumber'),
    exchangeRateAmount: number('exchangeRateAmount'),
    exchangeRateCurrency: string('exchangeRateCurrency'),
    indexRateAmount: number('indexRateAmount'),
    indexRateCurrency: string('indexRateCurrency'),
    payinAmount: number('payinAmount'),
    payinCurrency: string('payinCurrency'),
    payoutAmount: number('payoutAmount'),
    payoutCurrency: string('payoutCurrency'),
    orderStatus: string('orderStatus'),
    payinStatus: string('payinStatus'),
    payoutStatus: string('payoutStatus'),
    scheduledPayoutTime: string('scheduledPayoutTime'),
    createdAt: read<String>(json['createdAt'], 'createdAt'),
    completedAt: string('completedAt'),
    message: message == null ? null : parseOrderMessage(message),
    sentAt: string('sentAt'),
    payinMethod: string('payinMethod'),
    payoutMethod: string('payoutMethod'),
    triggerType: string('triggerType'),
    confirmationDeadline: string('confirmationDeadline'),
    bitcoinTransactionId: string('bitcoinTransactionId'),
    lnUrl: string('lnUrl'),
    lightningVoucherExpiresAt: string('lightningVoucherExpiresAt'),
    isPPBitcoinOutUpdatable: read<bool?>(
      json['isPPBitcoinOutUpdatable'],
      'isPPBitcoinOutUpdatable',
    ),
    payinAmountChanged: payinAmountChanged == null
        ? null
        : parseOrderPayinAmountChanged(payinAmountChanged),
    lightningInvoice: string('lightningInvoice'),
    bitcoinAddress: string('bitcoinAddress'),
    liquidAddress: string('liquidAddress'),
    liquidTransactionId: string('liquidTransactionId'),
    lightningAddress: string('lightningAddress'),
    beneficiaryName: string('beneficiaryName'),
    beneficiaryLabel: string('beneficiaryLabel'),
    beneficiaryAccountNumber: string('beneficiaryAccountNumber'),
    beneficiaryETransferAddress: string('beneficiaryETransferAddress'),
    securityQuestion: string('securityQuestion'),
    securityAnswer: string('securityAnswer'),
    paymentDescription: string('paymentDescription'),
    unbatchedBuyOnchainFees: number('unbatchedBuyOnchainFees'),
    bip21URI: string('bip21URI'),
    payjoinDetails: payjoinDetails == null
        ? null
        : parseOrderPayjoinDetails(payjoinDetails),
    referenceNumber: string('referenceNumber'),
    originName: string('originName'),
    originCedula: string('originCedula'),
  );
}

OrderMessage parseOrderMessage(Map<String, dynamic> json) => OrderMessage(
  code: json['code']?.toString(),
  message: json['message']?.toString(),
);

OrderPayinAmountChanged parseOrderPayinAmountChanged(
  Map<String, dynamic> json,
) => OrderPayinAmountChanged(
  requestedAmount: read<num?>(
    json['requestedAmount'],
    'requestedAmount',
  )?.toDouble(),
  receivedAmount: read<num?>(
    json['receivedAmount'],
    'receivedAmount',
  )?.toDouble(),
);

OrderPayjoinDetails parseOrderPayjoinDetails(Map<String, dynamic> json) =>
    OrderPayjoinDetails(txid: read<String?>(json['txid'], 'txid'));
