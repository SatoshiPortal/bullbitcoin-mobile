import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SepaEurDetails build({
    String? virtualPayeeStatus,
    bool isConfidential = false,
  }) => SepaEurDetails.create(
    iban: 'DE89370400440532013000',
    isCorporate: false,
    firstname: 'Sat',
    lastname: 'Oshi',
    virtualPayeeStatus: switch (virtualPayeeStatus) {
      'ACTIVE' => SepaVirtualPayeeStatus.active,
      'CREATED' => SepaVirtualPayeeStatus.created,
      'PROCESSING' => SepaVirtualPayeeStatus.processing,
      null => SepaVirtualPayeeStatus.absent,
      _ => SepaVirtualPayeeStatus.unknown,
    },
    isConfidential: isConfidential,
  );

  group('SepaEurDetails default', () {
    test('is a non-confidential regular SEPA with no virtual payee', () {
      final details = build();

      expect(details.isConfidential, isFalse);
      expect(details.type, RecipientType.sepaEur);
      expect(details.virtualPayeeStatus, SepaVirtualPayeeStatus.absent);
      expect(details.hasVirtualPayee, isFalse);
      expect(details.isVirtualPayeeActive, isFalse);
    });
  });

  group('SepaEurDetails confidential', () {
    test('reports the confidential type when created confidential', () {
      final details = build(isConfidential: true);

      expect(details.isConfidential, isTrue);
      expect(details.type, RecipientType.confidentialSepaEur);
    });
  });

  group('virtualPayeeStatus', () {
    test('ACTIVE is active and present', () {
      final details = build(virtualPayeeStatus: 'ACTIVE');

      expect(details.isVirtualPayeeActive, isTrue);
      expect(details.hasVirtualPayee, isTrue);
      expect(details.isVirtualPayeeProcessing, isFalse);
    });

    test('CREATED is processing and present but not yet active', () {
      final details = build(virtualPayeeStatus: 'CREATED');

      expect(details.isVirtualPayeeProcessing, isTrue);
      expect(details.isVirtualPayeeActive, isFalse);
      expect(details.hasVirtualPayee, isTrue);
    });

    test('PROCESSING is present and does not request activation again', () {
      final details = build(virtualPayeeStatus: 'PROCESSING');

      expect(details.isVirtualPayeeProcessing, isTrue);
      expect(details.isVirtualPayeeActive, isFalse);
      expect(details.hasVirtualPayee, isTrue);
    });

    test('unknown is neither present nor processing', () {
      final details = build(virtualPayeeStatus: 'UNRECOGNIZED');

      expect(details.isVirtualPayeeProcessing, isFalse);
      expect(details.isVirtualPayeeActive, isFalse);
      expect(details.hasVirtualPayee, isFalse);
    });
  });

  group('asConfidential', () {
    test('copies to a confidential type, preserving the other fields', () {
      final details = build(virtualPayeeStatus: 'CREATED');

      final confidential = details.asConfidential();

      expect(confidential.isConfidential, isTrue);
      expect(confidential.type, RecipientType.confidentialSepaEur);
      expect(confidential.iban, details.iban);
      expect(confidential.firstname, details.firstname);
      expect(confidential.lastname, details.lastname);
      expect(confidential.virtualPayeeStatus, SepaVirtualPayeeStatus.created);
    });
  });
}
