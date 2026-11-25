import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:exchange/src/recipients/data/sepa_virtual_payee_status_mapper.dart';
import 'package:test/test.dart';

void main() {
  test('known values', () {
    final table = {
      null: SepaVirtualPayeeStatus.absent,
      'ACTIVE': SepaVirtualPayeeStatus.active,
      'active': SepaVirtualPayeeStatus.active,
      'CREATED': SepaVirtualPayeeStatus.pending,
      'PROCESSING': SepaVirtualPayeeStatus.pending,
      'PENDING': SepaVirtualPayeeStatus.pending,
    };
    for (final MapEntry(key: raw, value: status) in table.entries) {
      expect(sepaVirtualPayeeStatusFromApi(raw), status, reason: '$raw');
    }
  });

  test(
    'another value is unknown, not pending, and is logged once (RCP-11)',
    () {
      expect(
        sepaVirtualPayeeStatusFromApi('REJECTED'),
        SepaVirtualPayeeStatus.unknown,
      );
      expect(
        UnknownServerValues.report('SEPA virtual payee status', 'REJECTED'),
        isFalse,
      );
    },
  );

  test('predicates', () {
    expect(SepaVirtualPayeeStatus.unknown.exists, isTrue);
    expect(SepaVirtualPayeeStatus.unknown.isActive, isFalse);
    for (final status in SepaVirtualPayeeStatus.values) {
      expect(
        status.isTerminal,
        status == SepaVirtualPayeeStatus.active ||
            status == SepaVirtualPayeeStatus.unknown,
        reason: '$status',
      );
    }
  });
}
