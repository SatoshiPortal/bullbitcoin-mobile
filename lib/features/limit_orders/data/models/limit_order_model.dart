import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';

final class LimitOrderModel {
  final String limitOrderId;
  final String limitOrderNumber;
  final String fiatAmount;
  final String currencyCode;
  final String limitPrice;
  final String estimatedBtcAmount;
  final String status;
  final String createdAt;
  final String expiresAt;
  final String? executedAt;
  final String? cancelledAt;
  final String? executedOrderId;
  final String address;

  const LimitOrderModel({
    required this.limitOrderId,
    required this.limitOrderNumber,
    required this.fiatAmount,
    required this.currencyCode,
    required this.limitPrice,
    required this.estimatedBtcAmount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.address,
    this.executedAt,
    this.cancelledAt,
    this.executedOrderId,
  });

  factory LimitOrderModel.fromJson(Map<String, dynamic> json) {
    return LimitOrderModel(
      limitOrderId: json['limitOrderId'] as String,
      limitOrderNumber: json['limitOrderNbr'] as String? ?? '',
      fiatAmount: json['fiatAmount'] as String,
      currencyCode: json['currencyCode'] as String,
      limitPrice: json['limitPrice'] as String,
      estimatedBtcAmount: json['estimatedBtcAmount'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      expiresAt: json['expiresAt'] as String,
      executedAt: json['executedAt'] as String?,
      cancelledAt: json['cancelledAt'] as String?,
      executedOrderId: json['executedOrderId'] as String?,
      address: json['address'] as String? ?? '',
    );
  }

  LimitOrder toEntity() => LimitOrder(
    id: limitOrderId,
    number: limitOrderNumber,
    fiatAmount: double.parse(fiatAmount),
    currencyCode: currencyCode,
    limitPrice: double.parse(limitPrice),
    estimatedBtcAmount: double.parse(estimatedBtcAmount),
    status: LimitOrderStatus.fromValue(status),
    createdAt: DateTime.parse(createdAt),
    expiresAt: DateTime.parse(expiresAt),
    executedAt: executedAt == null ? null : DateTime.parse(executedAt!),
    cancelledAt: cancelledAt == null ? null : DateTime.parse(cancelledAt!),
    executedOrderId: executedOrderId,
    address: address,
  );
}
