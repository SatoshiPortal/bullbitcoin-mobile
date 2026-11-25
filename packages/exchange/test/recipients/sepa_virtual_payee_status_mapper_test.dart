import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('virtual payee status from the api', () {
    test('no status means no virtual payee', () {
      expect(
        sepaVirtualPayeeStatusFromApi(null),
        SepaVirtualPayeeStatus.absent,
      );
    });

    test('ACTIVE means an active virtual payee', () {
      expect(
        sepaVirtualPayeeStatusFromApi('ACTIVE'),
        SepaVirtualPayeeStatus.active,
      );
      expect(
        sepaVirtualPayeeStatusFromApi('active'),
        SepaVirtualPayeeStatus.active,
      );
    });

    test('any other status means a pending virtual payee', () {
      expect(
        sepaVirtualPayeeStatusFromApi('CREATED'),
        SepaVirtualPayeeStatus.pending,
      );
      expect(
        sepaVirtualPayeeStatusFromApi('PROCESSING'),
        SepaVirtualPayeeStatus.pending,
      );
    });
  });
}
