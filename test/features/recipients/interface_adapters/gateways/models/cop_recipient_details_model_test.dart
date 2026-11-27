import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:bb_mobile/features/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the app sends for a recipient the user filled in.
Map<String, dynamic> _sent(RecipientFormDataModel form) =>
    RecipientDetailsModel.fromDomain(form.toDto().toDomain()).toJson();

RecipientDetails _saved(Map<String, dynamic> json) =>
    RecipientDetailsModel.fromJson(json).toDomain();

const _person = CopIndividualFormData(firstName: 'Ada', lastName: 'Lovelace');
const _company = CopCorporateFormData(corporateName: 'ACME SAS');

PseColombiaFormDataModel _pse({
  CopHolderFormData holder = _person,
  String email = 'ada@example.co',
}) => PseColombiaFormDataModel(
  bankCode: '1007',
  accountType: 'S',
  bankAccount: '123456',
  documentType: 'CC',
  documentId: '99',
  holder: holder,
  email: email,
);

NequiColombiaFormDataModel _nequi({
  CopHolderFormData holder = _person,
  String email = 'ada@example.co',
}) => NequiColombiaFormDataModel(
  phoneNumber: '3001234567',
  documentType: 'CC',
  documentId: '99',
  holder: holder,
  email: email,
);

void main() {
  // The keys of API-Recipients' recipientOutCOPBankAccountSchema and
  // recipientOutCOPNequiSchema, next to the common recipient keys.
  const common = {'recipientTypeFiat', 'isArchived', 'isDefault'};
  const person = {'isCorporate', 'name', 'lastname'};
  const company = {'isCorporate', 'corporateName'};
  const pse = {
    'email',
    'bankCode',
    'accountType',
    'bankAccount',
    'documentId',
    'documentType',
  };
  const nequi = {'email', 'bankAccount', 'documentId', 'documentType'};

  group('a new Colombian recipient sends what the API requires', () {
    test('PSE for a person', () {
      final json = _sent(_pse());

      expect(json.keys.toSet(), {...common, ...person, ...pse});
      expect(json['recipientTypeFiat'], 'PSE_COLOMBIA_COP');
      expect(json['isCorporate'], false);
      expect(json['name'], 'Ada');
      expect(json['lastname'], 'Lovelace');
      expect(json['email'], 'ada@example.co');
    });

    test('PSE for a company', () {
      final json = _sent(_pse(holder: _company));

      expect(json.keys.toSet(), {...common, ...company, ...pse});
      expect(json['isCorporate'], true);
      expect(json['corporateName'], 'ACME SAS');
    });

    test('Nequi for a person, with the phone as the bank account', () {
      final json = _sent(_nequi());

      expect(json.keys.toSet(), {...common, ...person, ...nequi});
      expect(json['recipientTypeFiat'], 'NEQUI_COLOMBIA_COP');
      expect(json['bankAccount'], '3001234567');
    });

    test('Nequi for a company', () {
      final json = _sent(_nequi(holder: _company));

      expect(json.keys.toSet(), {...common, ...company, ...nequi});
    });

    test('cannot be built without an email, a last name or a company name', () {
      for (final form in [
        _pse(email: ''),
        _pse(email: 'not-an-email'),
        _pse(
          holder: const CopIndividualFormData(firstName: 'Ada', lastName: ''),
        ),
        _nequi(holder: const CopCorporateFormData(corporateName: ' ')),
        _nequi(email: ''),
      ]) {
        expect(() => form.toDto().toDomain(), throwsA(anything));
      }
    });
  });

  group('a Colombian recipient the API holds', () {
    test('with a person and an email reads back as a full contact', () {
      final details =
          _saved({
                'recipientTypeFiat': 'PSE_COLOMBIA_COP',
                'isCorporate': false,
                'name': 'Ada',
                'lastname': 'Lovelace',
                'email': 'ada@example.co',
                'bankCode': '1007',
                'accountType': 'S',
                'bankAccount': '123456',
                'documentId': '99',
                'documentType': 'CC',
              })
              as PseColombiaDetails;

      final payee = details.payee as ColombiaContact;
      expect(payee.holder, isA<CopIndividual>());
      expect(payee.displayName, 'Ada Lovelace');
    });

    test('of a company is listed by the company name', () {
      final details =
          _saved({
                'recipientTypeFiat': 'NEQUI_COLOMBIA_COP',
                'isCorporate': true,
                'corporateName': 'ACME SAS',
                'email': 'pay@acme.co',
                'bankAccount': '3001234567',
                'documentId': '900123',
                'documentType': 'NIT',
              })
              as NequiColombiaDetails;

      expect(details.payee.displayName, 'ACME SAS');
      expect(details.phoneNumber, '3001234567');
    });

    test('saved with only a name and no email is still listed', () {
      final details =
          _saved({
                'recipientTypeFiat': 'PSE_COLOMBIA_COP',
                'name': 'Ada Lovelace',
                'bankCode': '1007',
                'accountType': 'S',
                'bankAccount': '123456',
                'bankName': 'Bancolombia',
                'documentId': '99',
                'documentType': 'CC',
              })
              as PseColombiaDetails;

      expect(details.payee, isA<ColombiaNameOnly>());
      expect(details.payee.displayName, 'Ada Lovelace');
    });
  });
}
