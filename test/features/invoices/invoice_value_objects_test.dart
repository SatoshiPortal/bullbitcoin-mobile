import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_url.dart';
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

  group('InvoiceUrl', () {
    test('accepts an HTTPS URL', () {
      expect(
        InvoiceUrl('https://bullpay.ca/invoice/inv-1').value,
        'https://bullpay.ca/invoice/inv-1',
      );
    });

    test('rejects a non-HTTPS URL', () {
      expect(() => InvoiceUrl('http://bullpay.ca/invoice/1'), throwsArgumentError);
    });

    test('rejects a javascript: scheme', () {
      expect(() => InvoiceUrl('javascript:alert(1)'), throwsArgumentError);
    });

    test('rejects an unparseable value', () {
      expect(() => InvoiceUrl('not a url'), throwsArgumentError);
    });
  });
}
