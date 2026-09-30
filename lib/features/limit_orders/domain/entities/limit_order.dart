enum LimitOrderStatus {
  active('ACTIVE'),
  executed('EXECUTED'),
  cancelled('CANCELLED'),
  expired('EXPIRED'),
  failed('FAILED');

  final String value;

  const LimitOrderStatus(this.value);

  static LimitOrderStatus fromValue(String value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => LimitOrderStatus.failed,
  );
}

final class LimitOrder {
  final String id;
  final String number;
  final double fiatAmount;
  final String currencyCode;
  final double limitPrice;
  final double estimatedBtcAmount;
  final LimitOrderStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? executedAt;
  final DateTime? cancelledAt;
  final String? executedOrderId;
  final String address;

  LimitOrder({
    required this.id,
    required this.number,
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

  bool get isActive => status == LimitOrderStatus.active;
}
