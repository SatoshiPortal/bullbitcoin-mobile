import 'package:meta/meta.dart';

import 'order_quote_event.dart';
import 'order_quote_state.dart';

@immutable
sealed class OrderStepEffect<R> {
  const OrderStepEffect();
}

/// Send the create through the account's write gate ([runOrderCreate]);
/// answer [OrderCreateAnswered] for [attempt].
final class OrderSendCreate<R> extends OrderStepEffect<R> {
  final R request;
  final int attempt;

  const OrderSendCreate(this.request, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is OrderSendCreate &&
      other.request == request &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(OrderSendCreate, request, attempt);

  @override
  String toString() => 'OrderSendCreate($request, $attempt)';
}

/// Read recent orders and match [request]; answer [OrderFindAnswered].
final class OrderFindCreated<R> extends OrderStepEffect<R> {
  final R request;
  final int attempt;

  const OrderFindCreated(this.request, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is OrderFindCreated &&
      other.request == request &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(OrderFindCreated, request, attempt);

  @override
  String toString() => 'OrderFindCreated($request, $attempt)';
}

/// Arm the lock timer of [orderId] from the order's expiry; answer
/// [OrderLockDue].
final class OrderStartLockTimer<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderStartLockTimer(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderStartLockTimer && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderStartLockTimer, orderId);

  @override
  String toString() => 'OrderStartLockTimer($orderId)';
}

/// Read [orderId] again; answer [OrderRefreshed].
final class OrderRefresh<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderRefresh(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderRefresh && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderRefresh, orderId);

  @override
  String toString() => 'OrderRefresh($orderId)';
}

/// Wait before refresh number [failures] + 1; answer [OrderRetryDue].
final class OrderScheduleRefreshRetry<R> extends OrderStepEffect<R> {
  final String orderId;
  final int failures;

  const OrderScheduleRefreshRetry(this.orderId, this.failures);

  @override
  bool operator ==(Object other) =>
      other is OrderScheduleRefreshRetry &&
      other.orderId == orderId &&
      other.failures == failures;

  @override
  int get hashCode => Object.hash(OrderScheduleRefreshRetry, orderId, failures);

  @override
  String toString() => 'OrderScheduleRefreshRetry($orderId, $failures)';
}

/// Cancel the lock and retry timers of [orderId].
final class OrderStopTimers<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderStopTimers(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderStopTimers && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderStopTimers, orderId);

  @override
  String toString() => 'OrderStopTimers($orderId)';
}

/// The user left a held order: release what it holds (a payjoin receiver).
final class OrderRelease<R> extends OrderStepEffect<R> {
  final String orderId;

  const OrderRelease(this.orderId);

  @override
  bool operator ==(Object other) =>
      other is OrderRelease && other.orderId == orderId;

  @override
  int get hashCode => Object.hash(OrderRelease, orderId);

  @override
  String toString() => 'OrderRelease($orderId)';
}
