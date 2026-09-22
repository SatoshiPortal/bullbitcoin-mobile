import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confidential SEPA enforces the virtual-payee eligibility fields', () {
    const form = SepaEurFormDataModel(
      iban: 'FR7630006000011234567890189',
      isCorporate: true,
      isOwner: false,
      firstname: 'Alice',
      lastname: 'Example',
      corporateName: 'Example SA',
      isConfidential: true,
    );

    final dto = form.toDto();

    expect(dto.recipientType, RecipientType.confidentialSepaEur);
    expect(dto.isOwner, isTrue);
    expect(dto.isCorporate, isFalse);
    expect(dto.firstname, 'Alice');
    expect(dto.lastname, 'Example');
    expect(dto.corporateName, isNull);
  });

  test('regular SEPA preserves ownership and corporate fields', () {
    const form = SepaEurFormDataModel(
      iban: 'FR7630006000011234567890189',
      isCorporate: true,
      isOwner: false,
      corporateName: 'Example SA',
    );

    final dto = form.toDto();

    expect(dto.recipientType, RecipientType.sepaEur);
    expect(dto.isOwner, isFalse);
    expect(dto.isCorporate, isTrue);
    expect(dto.corporateName, 'Example SA');
  });
}
