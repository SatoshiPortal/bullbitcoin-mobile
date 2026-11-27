import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:bb_mobile/features/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the app sends for a recipient the user filled in.
Map<String, dynamic> _sent(RecipientFormDataModel form) =>
    RecipientDetailsModel.fromDomain(form.toDto().toDomain()).toJson();

RecipientDetails _saved(Map<String, dynamic> json) =>
    RecipientDetailsModel.fromJson(json).toDomain();

void main() {
  test('a new recipient with a mistyped CLABE, phone or card is refused', () {
    for (final form in <RecipientFormDataModel>[
      const SpeiClabeMxnFormDataModel(clabe: '032180000118359718', name: 'Ada'),
      const SpeiSmsMxnFormDataModel(
        institutionCode: '40012',
        phone: '551234567',
        name: 'Ada',
      ),
      const SpeiCardMxnFormDataModel(
        institutionCode: '40012',
        debitcard: '411111111111111',
        name: 'Ada',
      ),
    ]) {
      expect(() => form.toDto().toDomain(), throwsA(isA<ArgumentError>()));
    }
  });

  test('a new recipient with valid numbers is sent as typed', () {
    final json = _sent(
      const SpeiClabeMxnFormDataModel(clabe: '032180000118359719', name: 'Ada'),
    );

    expect(json['clabe'], '032180000118359719');
  });

  test('a recipient the API holds is listed as it is', () {
    final details =
        _saved({
              'recipientTypeFiat': 'SPEI_CLABE_MXN',
              'clabe': '12345',
              'name': 'Ada',
            })
            as SpeiClabeMxnDetails;

    expect(details.clabe, '12345');
  });
}
