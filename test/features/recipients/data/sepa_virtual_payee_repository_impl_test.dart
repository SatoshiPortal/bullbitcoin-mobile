import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/sepa_virtual_payee_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _recipientJson({required String typeField}) => {
  'recipientId': 'recipient-1',
  'userId': 'user-1',
  'userNbr': 42,
  'isArchived': false,
  'createdAt': '2026-09-03T12:00:00.000Z',
  'updatedAt': '2026-09-03T12:01:00.000Z',
  typeField: typeField == 'recipientType' ? 'OUT_SEPA' : 'SEPA_EUR',
  'iban': 'DE89370400440532013000',
  'isOwner': true,
  'isCorporate': false,
  'firstname': 'Sat',
  'lastname': 'Oshi',
  'virtualPayeeStatus': 'ACTIVE',
  'paymentProcessors': ['CONFIDENTIAL_SEPA'],
};

void main() {
  late _MockDio mainnetDio;
  late _MockDio testnetDio;
  late SepaVirtualPayeeRepositoryImpl repository;

  setUp(() {
    mainnetDio = _MockDio();
    testnetDio = _MockDio();
    repository = SepaVirtualPayeeRepositoryImpl(mainnetDio, testnetDio);
  });

  test('activates through the selected environment client', () async {
    when(
      () => testnetDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {
          'result': {'element': _recipientJson(typeField: 'recipientType')},
        },
      ),
    );

    final result = await repository.activate(
      recipientId: 'recipient-1',
      isTestnet: true,
    );

    final recipient = (result as Ok<Recipient, RecipientsFailure>).value;
    expect(recipient.type, RecipientType.sepaEur);
    expect(
      (recipient.details as SepaEurDetails).virtualPayeeStatus,
      SepaVirtualPayeeStatus.active,
    );
    verifyNever(
      () => mainnetDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
  });

  test('find returns a confidential recipient view', () async {
    when(
      () => mainnetDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {
          'result': {
            'elements': [_recipientJson(typeField: 'recipientTypeFiat')],
            'totalElements': 1,
          },
        },
      ),
    );

    final result = await repository.find(
      recipientId: 'recipient-1',
      isTestnet: false,
    );

    final recipient = (result as Ok<Recipient?, RecipientsFailure>).value!;
    expect(recipient.type, RecipientType.confidentialSepaEur);
  });
}
