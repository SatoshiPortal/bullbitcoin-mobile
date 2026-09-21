import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/recipient_update_datasource.dart';
import 'package:bb_mobile/features/recipients/data/recipient_update_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late RecipientUpdateRepositoryImpl repository;

  setUp(() {
    dio = _MockDio();
    repository = RecipientUpdateRepositoryImpl(
      RecipientUpdateDatasource(dio, dio),
    );
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {'result': <String, dynamic>{}},
      ),
    );
  });

  test('updates an Interac recipient using the backend type', () async {
    await repository.update(
      'recipient-1',
      InteracEmailCadDetails.create(
        email: 'person@example.com',
        name: 'Person',
        isOwner: true,
      ),
      isTestnet: false,
    );

    final invocation = verify(
      () => dio.post(
        '/ak/api-recipients',
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    final request = invocation[0] as Map<String, dynamic>;
    final options = invocation[1] as Options;

    expect(request, {
      'jsonrpc': '2.0',
      'id': '0',
      'method': 'updateMyRecipient',
      'params': {
        'element': {
          'recipientId': 'recipient-1',
          'recipientType': 'OUT_INTERAC_EMAIL',
          'label': null,
          'isOwner': true,
          'email': 'person@example.com',
          'name': 'Person',
          'securityQuestion': null,
          'securityAnswer': null,
        },
      },
    });
    expect(options.headers, {'x-api-version': '2.0.0'});
  });

  test('includes currency when updating a SINPE IBAN recipient', () async {
    await repository.update(
      'recipient-1',
      SinpeIbanUsdDetails.create(
        iban: 'CR05015202001026284066',
        ownerName: 'Person',
      ),
      isTestnet: false,
    );

    final request =
        verify(
              () => dio.post(
                '/ak/api-recipients',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    final element =
        (request['params'] as Map<String, dynamic>)['element']
            as Map<String, dynamic>;

    expect(element['recipientType'], 'IBAN_CR');
    expect(element['currency'], 'USD');
    expect(element, isNot(contains('ownerName')));
    expect(element, isNot(contains('recipientTypeFiat')));
    expect(element, isNot(contains('isDefault')));
    expect(element, isNot(contains('isArchived')));
  });

  test('only sends editable bill-payment fields', () async {
    await repository.update(
      'recipient-1',
      BillPaymentCadDetails.create(
        payeeName: 'Hydro Quebec',
        payeeCode: 'HQ',
        payeeAccountNumber: '123456789',
        label: 'Power',
      ),
      isTestnet: false,
    );

    final request =
        verify(
              () => dio.post(
                '/ak/api-recipients',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    final element =
        (request['params'] as Map<String, dynamic>)['element']
            as Map<String, dynamic>;

    expect(element['payeeAccountNumber'], '123456789');
    expect(element['label'], 'Power');
    expect(element, isNot(contains('payeeName')));
    expect(element, isNot(contains('payeeCode')));
  });

  test('sends null values needed to clear editable fields', () async {
    await repository.update(
      'recipient-1',
      SepaEurDetails.create(
        iban: 'FR7630006000011234567890189',
        isCorporate: true,
        corporateName: 'Bull Bitcoin',
      ),
      isTestnet: false,
    );

    final request =
        verify(
              () => dio.post(
                '/ak/api-recipients',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    final element =
        (request['params'] as Map<String, dynamic>)['element']
            as Map<String, dynamic>;

    expect(element['label'], isNull);
    expect(element['firstname'], isNull);
    expect(element['lastname'], isNull);
    expect(element['corporateName'], 'Bull Bitcoin');
    expect(element, isNot(contains('isCorporate')));
  });

  test('preserves required Colombia recipient fields on update', () async {
    await repository.update(
      'recipient-1',
      PseColombiaDetails.create(
        name: 'John',
        lastname: 'Doe',
        email: 'john@example.com',
        isCorporate: false,
        accountType: 'S',
        bankAccount: '1234567890',
        bankCode: '007',
        bankName: 'Bancolombia',
        documentId: '123456789',
        documentType: 'CC',
      ),
      isTestnet: false,
    );

    final request =
        verify(
              () => dio.post(
                '/ak/api-recipients',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    final element =
        (request['params'] as Map<String, dynamic>)['element']
            as Map<String, dynamic>;

    expect(element['recipientType'], 'OUT_COP_BANK_ACCOUNT');
    expect(element['lastname'], 'Doe');
    expect(element['email'], 'john@example.com');
    expect(element['isCorporate'], isFalse);
    expect(element['corporateName'], isNull);
    expect(element, isNot(contains('bankName')));
  });

  test(
    'clears personal fields when Colombia recipient becomes corporate',
    () async {
      await repository.update(
        'recipient-1',
        NequiColombiaDetails.create(
          phoneNumber: '3001234567',
          documentId: '123456789',
          documentType: 'NIT',
          isCorporate: true,
          corporateName: 'Acme Colombia',
        ),
        isTestnet: false,
      );

      final request =
          verify(
                () => dio.post(
                  '/ak/api-recipients',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final element =
          (request['params'] as Map<String, dynamic>)['element']
              as Map<String, dynamic>;

      expect(element['name'], isNull);
      expect(element['lastname'], isNull);
      expect(element['corporateName'], 'Acme Colombia');
    },
  );

  test('returns invalid fields when the API rejects fields', () async {
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {
          'error': {
            'message': 'invalid recipient',
            'data': {
              'apiError': {
                'fields': {
                  'element': {
                    'email': [
                      {'code': 'ERR_VALIDATION_EMAIL'},
                    ],
                  },
                },
              },
            },
          },
        },
      ),
    );

    final result = await repository.update(
      'recipient-1',
      InteracEmailCadDetails.create(
        email: 'person@example.com',
        name: 'Person',
      ),
      isTestnet: false,
    );

    expect(result, isA<Err<void, RecipientsFailure>>());
    final failure = (result as Err<void, RecipientsFailure>).failure;
    expect(failure, isA<RecipientsInvalidFieldsFailure>());
    expect((failure as RecipientsInvalidFieldsFailure).fields, {'email'});
  });

  test('uses the same transport for saved Interac security details', () async {
    final details =
        (InteracSecurityDetails.create(
                  recipientId: 'recipient-1',
                  email: 'person@example.com',
                  securityQuestion: 'Favourite city?',
                  securityAnswer: 'Montreal',
                )
                as Ok<InteracSecurityDetails, RecipientsFailure>)
            .value;

    await repository.updateInteracSecurityDetails(details, isTestnet: false);

    final request =
        verify(
              () => dio.post(
                '/ak/api-recipients',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(request['method'], 'updateMyRecipient');
    expect(request['params'], {
      'element': {
        'recipientId': 'recipient-1',
        'recipientType': 'OUT_INTERAC_EMAIL',
        'email': 'person@example.com',
        'securityQuestion': 'Favourite city?',
        'securityAnswer': 'Montreal',
      },
    });
  });

  test('does not turn programmer errors into recoverable failures', () async {
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(StateError('bug'));

    expect(
      repository.update(
        'recipient-1',
        InteracEmailCadDetails.create(
          email: 'person@example.com',
          name: 'Person',
        ),
        isTestnet: false,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
