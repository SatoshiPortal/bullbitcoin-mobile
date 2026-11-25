import '../domain/entities/order.dart';
import 'unknown_server_value.dart';

/// The one mapper from the server's order status text. An unknown or missing
/// status is [OrderStatus.unknown] and is logged once.
OrderStatus orderStatusFromWire(String? raw) => serverValue(
  'order status',
  raw,
  values: OrderStatus.values,
  wire: (status) => status.value,
  unknown: OrderStatus.unknown,
);

/// The one mapper from the server's payin status text. An unknown or missing
/// status is [OrderPayinStatus.unknown] and is logged once.
OrderPayinStatus payinStatusFromWire(String? raw) => serverValue(
  'payin status',
  raw,
  values: OrderPayinStatus.values,
  wire: (status) => status.value,
  unknown: OrderPayinStatus.unknown,
);

/// The one mapper from the server's payout status text. An unknown or missing
/// status is [OrderPayoutStatus.unknown] and is logged once.
OrderPayoutStatus payoutStatusFromWire(String? raw) => serverValue(
  'payout status',
  raw,
  values: OrderPayoutStatus.values,
  wire: (status) => status.value,
  unknown: OrderPayoutStatus.unknown,
);
