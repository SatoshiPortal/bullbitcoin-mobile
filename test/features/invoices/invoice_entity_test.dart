import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
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

  group('publicUrlFor', () {
    test('unlinked uses /invoice/<id>', () {
      final invoice = _invoice(status: InvoiceStatus.unpaid, expiresAt: now);
      expect(
        invoice.publicUrlFor(domain: 'https://bullpay.ca'),
        'https://bullpay.ca/invoice/inv-1',
      );
    });

    test('linked uses /<nym>/i/<id> and trims a trailing slash', () {
      final invoice = _invoice(
        status: InvoiceStatus.unpaid,
        nymOwner: 'alice',
        expiresAt: now,
      );
      expect(
        invoice.publicUrlFor(domain: 'https://bullpay.ca/'),
        'https://bullpay.ca/alice/i/inv-1',
      );
    });
  });

  group('InvoiceStatus wire', () {
    test('round-trips every value', () {
      for (final status in InvoiceStatus.values) {
        expect(InvoiceStatus.fromWire(status.wire), status);
      }
    });

    test('maps unknown wire to unpaid (tolerant)', () {
      expect(InvoiceStatus.fromWire('brand_new_status'), InvoiceStatus.unpaid);
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
