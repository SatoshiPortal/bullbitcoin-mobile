import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:flutter_test/flutter_test.dart';

SepaEurDetails _individual({
  bool? isOwner = true,
  SepaVirtualPayeeStatus status = SepaVirtualPayeeStatus.absent,
}) => SepaEurDetails.create(
  iban: 'FR7630006000011234567890189',
  isCorporate: false,
  isOwner: isOwner,
  firstname: 'Satoshi',
  lastname: 'Nakamoto',
  virtualPayeeStatus: status,
);

void main() {
  group('virtual payee activation', () {
    test('an owned individual recipient can be activated', () {
      expect(_individual().canActivateVirtualPayee, isTrue);
    });

    test('a recipient the user does not own cannot be activated', () {
      expect(_individual(isOwner: false).canActivateVirtualPayee, isFalse);
      expect(_individual(isOwner: null).canActivateVirtualPayee, isFalse);
    });

    test('a corporate recipient cannot be activated', () {
      final corporate = SepaEurDetails.create(
        iban: 'FR7630006000011234567890189',
        isCorporate: true,
        isOwner: true,
        corporateName: 'Bull Bitcoin',
      );

      expect(corporate.canActivateVirtualPayee, isFalse);
    });
  });

  group('virtual payee status', () {
    test('no virtual payee exists before activation', () {
      final details = _individual();

      expect(details.hasVirtualPayee, isFalse);
      expect(details.isVirtualPayeeActive, isFalse);
    });

    test('a pending virtual payee exists but is not active', () {
      final details = _individual(status: SepaVirtualPayeeStatus.pending);

      expect(details.hasVirtualPayee, isTrue);
      expect(details.isVirtualPayeeActive, isFalse);
    });

    test('an active virtual payee is active', () {
      final details = _individual(status: SepaVirtualPayeeStatus.active);

      expect(details.hasVirtualPayee, isTrue);
      expect(details.isVirtualPayeeActive, isTrue);
    });
  });

  test('the confidential copy keeps the details and changes the type', () {
    final regular = _individual(status: SepaVirtualPayeeStatus.active);

    final confidential = regular.asConfidential();

    expect(regular.type, RecipientType.sepaEur);
    expect(confidential.type, RecipientType.confidentialSepaEur);
    expect(confidential.iban, regular.iban);
    expect(confidential.firstname, regular.firstname);
    expect(confidential.lastname, regular.lastname);
    expect(confidential.isOwner, regular.isOwner);
    expect(confidential.virtualPayeeStatus, SepaVirtualPayeeStatus.active);
  });
}
