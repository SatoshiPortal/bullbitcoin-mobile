import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice({
  required InvoiceStatus status,
  String? nymOwner,
  required DateTime expiresAt,
}) {
  return Invoice(
    id: InvoiceId('inv-1'),
    nymOwner: nymOwner,
    status: status,
    amountSat: 25000,
    remainingAmountSat: 25000,
    acceptBtc: false,
    acceptLn: true,
    acceptLiquid: true,
    createdAt: DateTime.utc(2024, 1, 1),
    expiresAt: expiresAt,
  );
}

void main() {
  final now = DateTime.utc(2024, 1, 2, 12);

  InvoiceStatusSnapshot snapshot(InvoiceStatus status) {
    return InvoiceStatusSnapshot(
      status: status,
      pricingMode: 'sat',
      settlementStatus: 'pending',
      amountSat: 25000,
      remainingAmountSat: 25000,
      paymentToleranceSat: 0,
      rateLocksUntil: now.add(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
      acceptBtc: true,
      acceptLn: true,
      acceptLiquid: true,
    );
  }

  group('isCancellable', () {
    test('true only for unpaid', () {
      for (final status in InvoiceStatus.values) {
        final invoice = _invoice(
          status: status,
          expiresAt: now.add(const Duration(days: 1)),
        );
        expect(invoice.isCancellable, status == InvoiceStatus.unpaid);
      }
    });
  });

  group('isPayable', () {
    test('unpaid before expiry is payable', () {
      expect(
        _invoice(
          status: InvoiceStatus.unpaid,
          expiresAt: now.add(const Duration(hours: 1)),
        ).isPayable(now),
        isTrue,
      );
    });

    test('unpaid past expiry is not payable', () {
      expect(
        _invoice(
          status: InvoiceStatus.unpaid,
          expiresAt: now.subtract(const Duration(hours: 1)),
        ).isPayable(now),
        isFalse,
      );
    });

    test('paid is never payable', () {
      expect(
        _invoice(
          status: InvoiceStatus.paid,
          expiresAt: now.add(const Duration(hours: 1)),
        ).isPayable(now),
        isFalse,
      );
    });

    test('unsupported is never payable even before expiry', () {
      expect(
        _invoice(
          status: InvoiceStatus.unsupported,
          expiresAt: now.add(const Duration(hours: 1)),
        ).isPayable(now),
        isFalse,
      );
    });
  });

  group('InvoiceStatusSnapshot actions', () {
    test('is cancellable only for unpaid', () {
      for (final status in InvoiceStatus.values) {
        expect(snapshot(status).isCancellable, status == InvoiceStatus.unpaid);
      }
    });

    test('unsupported is not terminal and not cancellable', () {
      final unsupported = snapshot(InvoiceStatus.unsupported);

      expect(unsupported.isTerminal, isFalse);
      expect(unsupported.isCancellable, isFalse);
    });
  });

  group('timeUntilExpiry', () {
    test('positive before expiry', () {
      final invoice = _invoice(
        status: InvoiceStatus.unpaid,
        expiresAt: now.add(const Duration(hours: 2)),
      );
      expect(invoice.timeUntilExpiry(now), const Duration(hours: 2));
    });

    test('zero when already expired', () {
      final invoice = _invoice(
        status: InvoiceStatus.unpaid,
        expiresAt: now.subtract(const Duration(hours: 2)),
      );
      expect(invoice.timeUntilExpiry(now), Duration.zero);
    });
  });

  group('InvoiceStatus wire', () {
    test('round-trips every value', () {
      for (final status in InvoiceStatus.values) {
        expect(InvoiceStatus.fromWire(status.wire), status);
      }
    });

    test('maps unknown wire to unsupported', () {
      final status = InvoiceStatus.fromWire('brand_new_status');

      expect(status, InvoiceStatus.unsupported);
      expect(status.wire, 'unsupported');
      expect(status.isUnsupported, isTrue);
    });

    test('terminal statuses are the settled set', () {
      expect(InvoiceStatus.paid.isTerminal, isTrue);
      expect(InvoiceStatus.expired.isTerminal, isTrue);
      expect(InvoiceStatus.cancelled.isTerminal, isTrue);
      expect(InvoiceStatus.unpaid.isTerminal, isFalse);
      expect(InvoiceStatus.partiallyPaid.isTerminal, isFalse);
    });
  });
}
