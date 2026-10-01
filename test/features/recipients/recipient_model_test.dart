import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/data/models/recipient_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses activateSepaVirtualPayee OUT_SEPA response', () {
    final model = RecipientModel.fromJson({
      'recipientId': 'recipient-1',
      'userId': 'user-1',
      'userNbr': 42,
      'isArchived': false,
      'createdAt': '2026-09-03T12:00:00.000Z',
      'updatedAt': '2026-09-03T12:01:00.000Z',
      'recipientType': 'OUT_SEPA',
      'iban': 'DE89370400440532013000',
      'isOwner': true,
      'isCorporate': false,
      'firstname': 'Sat',
      'lastname': 'Oshi',
      'virtualPayeeStatus': 'CREATED',
      'paymentProcessors': ['OUT_EUR_FIAT_REPUBLIC'],
    });

    final recipient = model.toDomain;
    final details = recipient.details as SepaEurDetails;

    expect(recipient.type, RecipientType.sepaEur);
    expect(details.iban, 'DE89370400440532013000');
    expect(details.virtualPayeeStatus, SepaVirtualPayeeStatus.created);
  });
}
