import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/order_status_wire.dart';
import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:test/test.dart';

void main() {
  group('order status', () {
    test('every known server text maps to its value', () {
      for (final status in OrderStatus.values) {
        if (status == OrderStatus.unknown) continue;
        expect(orderStatusFromWire(status.value), status);
      }
    });

    test('an unknown text is unknown and is logged once', () {
      expect(orderStatusFromWire('Refunding'), OrderStatus.unknown);
      expect(UnknownServerValues.report('order status', 'Refunding'), isFalse);
    });

    test('a missing status is unknown and is logged once', () {
      expect(orderStatusFromWire(null), OrderStatus.unknown);
      expect(UnknownServerValues.report('order status', null), isFalse);
    });

    test('the literal "Unknown" is not a known status', () {
      expect(orderStatusFromWire('Unknown'), OrderStatus.unknown);
      expect(UnknownServerValues.report('order status', 'Unknown'), isFalse);
    });

    test('predicates', () {
      final table = {
        OrderStatus.canceled: (terminal: true, failed: false, rejected: false),
        OrderStatus.expired: (terminal: true, failed: false, rejected: false),
        OrderStatus.orderExpired: (
          terminal: true,
          failed: false,
          rejected: false,
        ),
        OrderStatus.inProgress: (
          terminal: false,
          failed: false,
          rejected: false,
        ),
        OrderStatus.awaitingConfirmation: (
          terminal: false,
          failed: false,
          rejected: false,
        ),
        OrderStatus.completed: (terminal: true, failed: false, rejected: false),
        OrderStatus.rejected: (terminal: true, failed: false, rejected: true),
        OrderStatus.failed: (terminal: true, failed: true, rejected: false),
        OrderStatus.unknown: (terminal: false, failed: false, rejected: false),
      };
      expect(table.keys, containsAll(OrderStatus.values));
      for (final MapEntry(key: status, value: expected) in table.entries) {
        expect(status.isTerminal, expected.terminal, reason: '$status');
        expect(status.isFailed, expected.failed, reason: '$status');
        expect(status.isRejected, expected.rejected, reason: '$status');
      }
    });
  });

  group('payin status', () {
    test('every known server text maps to its value', () {
      for (final status in OrderPayinStatus.values) {
        if (status == OrderPayinStatus.unknown) continue;
        expect(payinStatusFromWire(status.value), status);
      }
    });

    test('an unknown or missing text is unknown and is logged once', () {
      expect(payinStatusFromWire('Refunded'), OrderPayinStatus.unknown);
      expect(payinStatusFromWire(null), OrderPayinStatus.unknown);
      expect(UnknownServerValues.report('payin status', 'Refunded'), isFalse);
      expect(UnknownServerValues.report('payin status', null), isFalse);
    });

    test('predicates', () {
      final terminal = {OrderPayinStatus.completed, OrderPayinStatus.rejected};
      for (final status in OrderPayinStatus.values) {
        expect(status.isTerminal, terminal.contains(status), reason: '$status');
        expect(status.isFailed, isFalse, reason: '$status');
        expect(
          status.isRejected,
          status == OrderPayinStatus.rejected,
          reason: '$status',
        );
      }
    });
  });

  group('payout status', () {
    test('every known server text maps to its value', () {
      for (final status in OrderPayoutStatus.values) {
        if (status == OrderPayoutStatus.unknown) continue;
        expect(payoutStatusFromWire(status.value), status);
      }
    });

    test('an unknown or missing text is unknown and is logged once', () {
      expect(payoutStatusFromWire('Reversed'), OrderPayoutStatus.unknown);
      expect(payoutStatusFromWire(null), OrderPayoutStatus.unknown);
      expect(UnknownServerValues.report('payout status', 'Reversed'), isFalse);
      expect(UnknownServerValues.report('payout status', null), isFalse);
    });

    test('predicates', () {
      final terminal = {
        OrderPayoutStatus.completed,
        OrderPayoutStatus.canceled,
        OrderPayoutStatus.failed,
      };
      for (final status in OrderPayoutStatus.values) {
        expect(status.isTerminal, terminal.contains(status), reason: '$status');
        expect(
          status.isFailed,
          status == OrderPayoutStatus.failed,
          reason: '$status',
        );
        expect(status.isRejected, isFalse, reason: '$status');
      }
    });
  });
}
