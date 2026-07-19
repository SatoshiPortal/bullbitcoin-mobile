import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvoiceId', () {
    test('accepts a non-empty id and trims it', () {
      expect(InvoiceId('  inv-1  ').value, 'inv-1');
    });

    test('rejects an empty id', () {
      expect(() => InvoiceId('   '), throwsArgumentError);
    });

    test('equality is by value', () {
      expect(InvoiceId('inv-1'), InvoiceId('inv-1'));
    });
  });

  group('PrivateInvoiceLink', () {
    final invoiceId = InvoiceId('inv-1');
    final origin = Uri.parse('https://pay2.bull-wallet.com');

    test('appends the local key to an approved fragmentless server URL', () {
      final link = PrivateInvoiceLink.fromServer(
        invoiceUrl: 'https://pay2.bull-wallet.com/invoice/inv-1',
        expectedInvoiceId: invoiceId,
        viewingKey: 'A' * 43,
        expectedOrigin: origin,
      );

      expect(
        link.value,
        'https://pay2.bull-wallet.com/invoice/inv-1#v1.${'A' * 43}',
      );
      expect(link.toString(), isNot(contains(link.value)));
    });

    test('accepts linked invoice paths', () {
      expect(
        PrivateInvoiceLink.fromServer(
          invoiceUrl: 'https://pay2.bull-wallet.com/alice/i/inv-1',
          expectedInvoiceId: invoiceId,
          viewingKey: 'A' * 43,
          expectedOrigin: origin,
        ).value,
        contains('/alice/i/inv-1#v1.'),
      );
    });

    test('rejects origin, id, query, fragment, and path substitutions', () {
      for (final value in [
        'https://evil.example/invoice/inv-1',
        'https://pay2.bull-wallet.com/invoice/inv-2',
        'https://pay2.bull-wallet.com/invoice/inv-1?next=evil',
        'https://pay2.bull-wallet.com/invoice/inv-1#existing',
        'https://pay2.bull-wallet.com/other/inv-1',
      ]) {
        expect(
          () => PrivateInvoiceLink.fromServer(
            invoiceUrl: value,
            expectedInvoiceId: invoiceId,
            viewingKey: 'A' * 43,
            expectedOrigin: origin,
          ),
          throwsArgumentError,
        );
      }
    });

    test('stored link requires an exact invoice path and fragment grammar', () {
      expect(
        () => PrivateInvoiceLink.stored(
          invoiceId: invoiceId,
          value:
              'https://pay2.bull-wallet.com/not-invoice/inv-1#v1.${'A' * 43}',
          expectedOrigin: origin,
        ),
        throwsArgumentError,
      );
    });

    test('stored link rejects a valid path on another origin', () {
      expect(
        () => PrivateInvoiceLink.stored(
          invoiceId: invoiceId,
          value: 'https://evil.example/invoice/inv-1#v1.${'A' * 43}',
          expectedOrigin: origin,
        ),
        throwsArgumentError,
      );
    });
  });
}
