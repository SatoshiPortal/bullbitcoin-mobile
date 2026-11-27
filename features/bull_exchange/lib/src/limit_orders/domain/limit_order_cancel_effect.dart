import 'package:meta/meta.dart';

import 'limit_order_cancel_event.dart';

@immutable
sealed class LimitCancelEffect {
  const LimitCancelEffect();
}

/// Cancel [orderId] through the write gate; answer [CancelAnswered].
final class CancelSend extends LimitCancelEffect {
  final String orderId;
  final int attempt;

  const CancelSend(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelSend &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelSend, orderId, attempt);
}

/// Read [orderId] again; answer [CancelChecked].
final class CancelRead extends LimitCancelEffect {
  final String orderId;
  final int attempt;

  const CancelRead(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelRead &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelRead, orderId, attempt);
}
