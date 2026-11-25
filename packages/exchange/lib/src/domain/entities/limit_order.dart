enum LimitOrderStatus {
  active('ACTIVE'),
  executed('EXECUTED'),
  cancelled('CANCELLED'),
  expired('EXPIRED'),
  failed('FAILED'),

  /// A status this build doesn't know. Not terminal: the order may still be
  /// open on the exchange, so it stays in the open list and counts toward the
  /// open-order cap.
  unknown('UNKNOWN');

  final String value;

  const LimitOrderStatus(this.value);

  bool get isTerminal => switch (this) {
    LimitOrderStatus.executed ||
    LimitOrderStatus.cancelled ||
    LimitOrderStatus.expired ||
    LimitOrderStatus.failed => true,
    LimitOrderStatus.active || LimitOrderStatus.unknown => false,
  };

  bool get isFailed => this == LimitOrderStatus.failed;

  /// The exchange has no rejected status for a limit order.
  bool get isRejected => false;
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

  /// Whether the user can still cancel it.
  bool get isActive => status == LimitOrderStatus.active;

  /// Whether it may still execute: active, or a status this build doesn't
  /// know.
  bool get isOpen => !status.isTerminal;
}
