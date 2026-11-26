import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/limit_order_status_wire.dart';
import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:test/test.dart';

void main() {
  test('every known server value maps to its status', () {
    expect(limitOrderStatusFromWire('ACTIVE'), LimitOrderStatus.active);
    expect(limitOrderStatusFromWire('EXECUTED'), LimitOrderStatus.executed);
    expect(limitOrderStatusFromWire('CANCELLED'), LimitOrderStatus.cancelled);
    expect(limitOrderStatusFromWire('EXPIRED'), LimitOrderStatus.expired);
    expect(limitOrderStatusFromWire('FAILED'), LimitOrderStatus.failed);
  });

  test('an unknown value is unknown, not failed, and is logged once', () {
    expect(limitOrderStatusFromWire('EXECUTING'), LimitOrderStatus.unknown);
    expect(
      UnknownServerValues.report('limit order status', 'EXECUTING'),
      isFalse,
    );
  });

  test('a missing value or the fallback name is unknown', () {
    expect(limitOrderStatusFromWire(null), LimitOrderStatus.unknown);
    expect(limitOrderStatusFromWire('UNKNOWN'), LimitOrderStatus.unknown);
    expect(
      UnknownServerValues.report('limit order status', 'UNKNOWN'),
      isFalse,
    );
  });
}
