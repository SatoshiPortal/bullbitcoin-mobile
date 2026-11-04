import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/datasources/bullbitcoin_api_virtual_iban_datasource.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

const _activeElement = {
  'recipientId': 'viban-1',
  'iban': 'FR7616958000016918327146718',
  'bicCode': 'FIRPFRP2',
  'bankAddress': '1 Rue de la Paix, Paris',
  'ibanCountry': 'FR',
};

Response<dynamic> _response(dynamic data, {int status = 200}) => Response(
  requestOptions: RequestOptions(path: '/ak/api-recipients'),
  statusCode: status,
  data: data,
);

Response<dynamic> _list(List<Map<String, dynamic>> elements) => _response({
  'result': {'elements': elements, 'totalElements': elements.length},
});

Response<dynamic> _apiError(String code) => _response({
  'error': {
    'code': -32602,
    'message': 'Invalid params',
    'data': {
      'apiError': {'code': code, 'message': 'refused'},
    },
  },
});

void main() {
  late _MockDio mainnet;
  late _MockDio testnet;
  late VirtualIbanRepositoryImpl repository;

  setUp(() {
    mainnet = _MockDio();
    testnet = _MockDio();
    repository = VirtualIbanRepositoryImpl(
      mainnetDatasource: BullbitcoinApiVirtualIbanDatasource(http: mainnet),
      testnetDatasource: BullbitcoinApiVirtualIbanDatasource(http: testnet),
    );
  });

  void stub(_MockDio dio, Object answer) {
    final call = when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
    if (answer is Response) {
      call.thenAnswer((_) async => answer);
    } else {
      call.thenThrow(answer);
    }
  }

  Map<String, dynamic> sentRequest(_MockDio dio) =>
      verify(
            () => dio.post<dynamic>(
              any(),
              data: captureAny(named: 'data'),
              options: any(named: 'options'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('find', () {
    test('asks the selected environment for the virtual IBAN', () async {
      stub(testnet, _list([]));

      final result = await repository.find(isTestnet: true);

      expect(result, isA<Ok<VirtualIban?, RecipientsFailure>>());
      final request = sentRequest(testnet);
      expect(request['method'], 'listRecipientsFiat');
      expect((request['params'] as Map)['filters'], {
        'recipientTypeFiat': ['SEPA_EUR_VIRTUAL_ACCOUNT'],
        'isOwner': true,
      });
      verifyNever(
        () => mainnet.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );
    });

    test('an empty list means the user has no virtual IBAN', () async {
      stub(mainnet, _list([]));

      final result = await repository.find(isTestnet: false);

      expect((result as Ok<VirtualIban?, RecipientsFailure>).value, isNull);
    });

    test('returns an active virtual IBAN', () async {
      stub(mainnet, _list([_activeElement]));

      final result = await repository.find(isTestnet: false);

      expect(
        (result as Ok<VirtualIban?, RecipientsFailure>).value,
        isA<ActiveVirtualIban>(),
      );
    });

    test('returns a pending virtual IBAN', () async {
      stub(
        mainnet,
        _list([
          {'recipientId': 'viban-1'},
        ]),
      );

      final result = await repository.find(isTestnet: false);

      expect(
        (result as Ok<VirtualIban?, RecipientsFailure>).value,
        isA<PendingVirtualIban>(),
      );
    });

    test('a refused funding option means no virtual IBAN yet', () async {
      stub(mainnet, _apiError('ERR_RCP_PO404'));

      final result = await repository.find(isTestnet: false);

      expect((result as Ok<VirtualIban?, RecipientsFailure>).value, isNull);
    });

    test('another refusal is unexpected', () async {
      stub(mainnet, _apiError('ERR_RCP_500'));

      final result = await repository.find(isTestnet: false);

      expect(
        (result as Err<VirtualIban?, RecipientsFailure>).failure,
        isA<RecipientsUnexpectedFailure>(),
      );
    });
  });

  group('create', () {
    test('creates the virtual IBAN for the user', () async {
      stub(
        mainnet,
        _response({
          'result': {'element': _activeElement},
        }),
      );

      final result = await repository.create(isTestnet: false);

      expect(
        (result as Ok<VirtualIban, RecipientsFailure>).value,
        isA<ActiveVirtualIban>(),
      );
      final request = sentRequest(mainnet);
      expect(request['method'], 'createMyRecipient');
      expect(request['params'], {
        'element': {'recipientType': 'FR_VIRTUAL_ACCOUNT', 'isOwner': true},
      });
    });

    Future<RecipientsFailure> failureFor(Object answer) async {
      stub(mainnet, answer);
      final result = await repository.create(isTestnet: false);
      return (result as Err<VirtualIban, RecipientsFailure>).failure;
    }

    test('a refused funding option is reported as not available', () async {
      expect(
        await failureFor(_apiError('ERR_RCP_PO404')),
        isA<RecipientsVirtualIbanNotAvailableFailure>(),
      );
    });

    test('a user outside the EU is told residency is required', () async {
      expect(
        await failureFor(_apiError('ERR_RCP_400_001')),
        isA<RecipientsEuResidencyRequiredFailure>(),
      );
    });

    test('a generic invalid request is unexpected', () async {
      expect(
        await failureFor(_apiError('ERR_RCP_400')),
        isA<RecipientsUnexpectedFailure>(),
      );
    });

    test('an unreachable API is a network failure', () async {
      expect(
        await failureFor(
          DioException(
            requestOptions: RequestOptions(path: '/ak/api-recipients'),
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<RecipientsNetworkFailure>(),
      );
    });
  });
}
