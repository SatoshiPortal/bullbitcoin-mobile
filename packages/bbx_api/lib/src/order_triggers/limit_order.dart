import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';

/// A limit order as `api-ordertrigger` returns it, with the server's raw
/// values: amounts, prices, the status and the dates are unparsed strings.
@immutable
class LimitOrder {
  final String limitOrderId;

  /// The order number shown to the user (`limitOrderNbr`).
  final String? limitOrderNumber;
  final String fiatAmount;
  final String currencyCode;
  final String limitPrice;
  final String estimatedBtcAmount;

  /// For example `ACTIVE`.
  final String status;
  final String createdAt;
  final String expiresAt;
  final String? executedAt;
  final String? cancelledAt;
  final String? executedOrderId;
  final String? address;

  const LimitOrder({
    required this.limitOrderId,
    this.limitOrderNumber,
    required this.fiatAmount,
    required this.currencyCode,
    required this.limitPrice,
    required this.estimatedBtcAmount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.executedAt,
    this.cancelledAt,
    this.executedOrderId,
    this.address,
  });

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory LimitOrder.fromJson(Map<String, dynamic> json) => LimitOrder(
    limitOrderId: read<String>(json['limitOrderId'], 'limitOrderId'),
    limitOrderNumber: read<String?>(json['limitOrderNbr'], 'limitOrderNbr'),
    fiatAmount: read<String>(json['fiatAmount'], 'fiatAmount'),
    currencyCode: read<String>(json['currencyCode'], 'currencyCode'),
    limitPrice: read<String>(json['limitPrice'], 'limitPrice'),
    estimatedBtcAmount: read<String>(
      json['estimatedBtcAmount'],
      'estimatedBtcAmount',
    ),
    status: read<String>(json['status'], 'status'),
    createdAt: read<String>(json['createdAt'], 'createdAt'),
    expiresAt: read<String>(json['expiresAt'], 'expiresAt'),
    executedAt: read<String?>(json['executedAt'], 'executedAt'),
    cancelledAt: read<String?>(json['cancelledAt'], 'cancelledAt'),
    executedOrderId: read<String?>(json['executedOrderId'], 'executedOrderId'),
    address: read<String?>(json['address'], 'address'),
  );
}
