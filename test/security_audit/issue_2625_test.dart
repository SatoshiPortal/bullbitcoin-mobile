// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2625
// Finding: CSV export emits attacker-controlled swap strings as spreadsheet formulas.
// Regression test for the fix.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV source neutralizes spreadsheet formula cells', () {
    final source = File(
      'lib/features/transactions/adapters/csv_transaction_export_formatter.dart',
    ).readAsStringSync();
    expect(source, contains('toFields().map(_escape).join'));
    expect(source, contains("value.contains(',')"));
    expect(source, contains("'=+-@\\t\\r'.contains(value[0])"));
    expect(source, contains(r'''value = "'$value'''));
  });
}
