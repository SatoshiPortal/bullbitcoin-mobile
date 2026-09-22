import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipientType.confidentialSepaEur', () {
    test('shares jurisdiction and currency with regular SEPA', () {
      expect(RecipientType.confidentialSepaEur.jurisdictionCode, 'EU');
      expect(RecipientType.confidentialSepaEur.currencyCode, 'EUR');
    });
  });

  group('typesForCurrency', () {
    test('EUR includes both regular and confidential SEPA', () {
      final types = RecipientType.typesForCurrency('EUR');
      expect(types, contains(RecipientType.sepaEur));
      expect(types, contains(RecipientType.confidentialSepaEur));
    });
  });

  group('fromValue', () {
    test(
      'SEPA_EUR resolves to regular SEPA, not the confidential synthetic',
      () {
        expect(RecipientType.fromValue('SEPA_EUR'), RecipientType.sepaEur);
      },
    );
  });

  group('supportsPaymentDescription', () {
    test('matches the processor-backed recipient types', () {
      expect(RecipientType.interacEmailCad.supportsPaymentDescription, isTrue);
      expect(RecipientType.bankTransferCad.supportsPaymentDescription, isTrue);
      expect(RecipientType.sepaEur.supportsPaymentDescription, isTrue);
      expect(
        RecipientType.confidentialSepaEur.supportsPaymentDescription,
        isTrue,
      );
      expect(RecipientType.sinpeMovilCrc.supportsPaymentDescription, isTrue);
      expect(RecipientType.sinpeIbanCrc.supportsPaymentDescription, isTrue);
      expect(RecipientType.sinpeIbanUsd.supportsPaymentDescription, isTrue);
    });

    test('rejects recipient types without processor support', () {
      expect(RecipientType.billPaymentCad.supportsPaymentDescription, isFalse);
      expect(RecipientType.speiClabeMxn.supportsPaymentDescription, isFalse);
      expect(
        RecipientType.bankAccountArgentina.supportsPaymentDescription,
        isFalse,
      );
      expect(RecipientType.pseColombia.supportsPaymentDescription, isFalse);
    });
  });
}
