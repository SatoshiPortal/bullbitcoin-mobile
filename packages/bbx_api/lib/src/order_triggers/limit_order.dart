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
}
