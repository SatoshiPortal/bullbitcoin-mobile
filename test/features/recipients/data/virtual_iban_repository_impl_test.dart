import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
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

  test('reports an active virtual IBAN when all bank details exist', () async {
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
            'elements': [
              {
                'iban': 'DE89370400440532013000',
                'bicCode': 'TESTBIC',
                'bankAddress': 'Test bank',
              },
            ],
          },
        },
      ),
    );

    final result = await repository.getStatus(isTestnet: false);

    expect(
      (result as Ok<VirtualIbanStatus, RecipientsFailure>).value,
      VirtualIbanStatus.active,
    );
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
      (result as Ok<VirtualIbanStatus, RecipientsFailure>).value,
      VirtualIbanStatus.pending,
    );
    verifyNever(() => mainnetDio.post(any(), data: any(named: 'data')));
  });
}
