import '../domain/entities/limit_order.dart';
import 'unknown_server_value.dart';

/// The one mapper from the server's limit-order status. An unknown or missing
/// status is [LimitOrderStatus.unknown] (never `failed`) and is logged once.
LimitOrderStatus limitOrderStatusFromWire(String? raw) => serverValue(
  'limit order status',
  raw,
  values: LimitOrderStatus.values,
  wire: (status) => status.value,
  unknown: LimitOrderStatus.unknown,
);
