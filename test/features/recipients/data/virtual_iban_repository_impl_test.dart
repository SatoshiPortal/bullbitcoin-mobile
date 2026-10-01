import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio mainnetDio;
  late _MockDio testnetDio;
  late VirtualIbanRepositoryImpl repository;

  setUp(() {
    mainnetDio = _MockDio();
    testnetDio = _MockDio();
    repository = VirtualIbanRepositoryImpl(mainnetDio, testnetDio);
  });

  void mockGetStatusResponse(Map<String, dynamic> data) {
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
        data: data,
      ),
    );
  }

  test('reports an active virtual IBAN when all bank details exist', () async {
    mockGetStatusResponse({
      'result': {
        'elements': [
          {
            'iban': 'DE89370400440532013000',
            'bicCode': 'TESTBIC',
            'bankAddress': 'Test bank',
            'ibanCountry': 'DE',
          },
        ],
      },
    });

    final result = await repository.getStatus(isTestnet: false);

    final virtualIban = (result as Ok<VirtualIban, RecipientsFailure>).value;
    expect(virtualIban.status, VirtualIbanStatus.active);
    expect(virtualIban.iban, 'DE89370400440532013000');
    expect(virtualIban.bicCode, 'TESTBIC');
    expect(virtualIban.bankAddress, 'Test bank');
    expect(virtualIban.ibanCountry, 'DE');
  });

  test('creates the virtual IBAN through the selected client', () async {
    when(() => testnetDio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {
          'result': {
            'element': {'virtualAccountStatus': 'CREATED'},
          },
        },
      ),
    );

    final result = await repository.create(isTestnet: true);

    expect(
      (result as Ok<VirtualIban, RecipientsFailure>).value.status,
      VirtualIbanStatus.pending,
    );
    verifyNever(() => mainnetDio.post(any(), data: any(named: 'data')));
  });

  test('maps ERR_RCP_PO404 to VirtualIbanNotAvailableFailure', () async {
    mockGetStatusResponse({
      'error': {
        'message': 'Payment option not available',
        'data': {
          'apiError': {
            'code': 'ERR_RCP_PO404',
            'en': 'Payment Option Not Available',
          },
        },
      },
    });

    final result = await repository.getStatus(isTestnet: false);

    expect(
      (result as Err<VirtualIban, RecipientsFailure>).failure,
      isA<VirtualIbanNotAvailableFailure>(),
    );
  });

  test('maps ERR_RCP_400 on creation to the EU residency failure', () async {
    when(() => mainnetDio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {
          'error': {
            'message': 'Invalid request',
            'data': {
              'apiError': {
                'code': 'ERR_RCP_400',
                'en':
                    'You need to be a resident of the European Union to create a virtual IBAN',
              },
            },
          },
        },
      ),
    );

    final result = await repository.create(isTestnet: false);

    final failure = (result as Err<VirtualIban, RecipientsFailure>).failure;
    expect(failure, isA<VirtualIbanEuResidencyRequiredFailure>());
    expect(failure.logMessage, contains('European Union'));
  });

  test('maps an unknown API error to VirtualIbanFailure', () async {
    mockGetStatusResponse({
      'error': {'message': 'boom'},
    });

    final result = await repository.getStatus(isTestnet: false);

    expect(
      (result as Err<VirtualIban, RecipientsFailure>).failure,
      isA<VirtualIbanFailure>(),
    );
  });
}
