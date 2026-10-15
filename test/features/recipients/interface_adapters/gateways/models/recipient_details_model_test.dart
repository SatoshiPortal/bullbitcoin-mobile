import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/models/recipient_details_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sepaJson({String? virtualPayeeStatus}) => {
  'recipientTypeFiat': 'SEPA_EUR',
  'isOwner': true,
  'iban': 'FR7630006000011234567890189',
  'isCorporate': false,
  'firstname': 'Satoshi',
  'lastname': 'Nakamoto',
  'virtualPayeeStatus': ?virtualPayeeStatus,
};

SepaVirtualPayeeStatus _statusOf(Map<String, dynamic> json) =>
    (RecipientDetailsModel.fromJson(json).toDomain() as SepaEurDetails)
        .virtualPayeeStatus;

void main() {
  group('virtual payee status from the api', () {
    test('no status means no virtual payee', () {
      expect(_statusOf(_sepaJson()), SepaVirtualPayeeStatus.absent);
    });

    test('ACTIVE means an active virtual payee', () {
      expect(
        _statusOf(_sepaJson(virtualPayeeStatus: 'ACTIVE')),
        SepaVirtualPayeeStatus.active,
      );
      expect(
        _statusOf(_sepaJson(virtualPayeeStatus: 'active')),
        SepaVirtualPayeeStatus.active,
      );
    });

    test('any other status means a pending virtual payee', () {
      expect(
        _statusOf(_sepaJson(virtualPayeeStatus: 'CREATED')),
        SepaVirtualPayeeStatus.pending,
      );
      expect(
        _statusOf(_sepaJson(virtualPayeeStatus: 'PROCESSING')),
        SepaVirtualPayeeStatus.pending,
      );
    });
  });

  test('a confidential recipient is sent to the api as a SEPA recipient', () {
    final details = SepaEurDetails.create(
      iban: 'FR7630006000011234567890189',
      isCorporate: false,
      isOwner: true,
      firstname: 'Satoshi',
      lastname: 'Nakamoto',
      virtualPayeeStatus: SepaVirtualPayeeStatus.active,
    ).asConfidential();

    final json = RecipientDetailsModel.fromDomain(details).toJson();

    expect(json['recipientTypeFiat'], 'SEPA_EUR');
    expect(json.containsKey('virtualPayeeStatus'), isFalse);
  });
}
