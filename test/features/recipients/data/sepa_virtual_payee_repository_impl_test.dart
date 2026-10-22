import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/bullbitcoin_api_sepa_virtual_payee_datasource.dart';
import 'package:bb_mobile/features/recipients/data/sepa_virtual_payee_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _response(dynamic data) => Response(
  requestOptions: RequestOptions(path: '/ak/api-recipients'),
  statusCode: 200,
  data: data,
);

Map<String, dynamic> _payee(String id, {String? status}) => {
  'recipientId': id,
  'recipientTypeFiat': 'SEPA_EUR',
  'iban': 'FR7630006000011234567890189',
  'virtualPayeeStatus': ?status,
};

Response<dynamic> _page(List<Map<String, dynamic>> elements, int total) =>
    _response({
      'result': {'elements': elements, 'totalElements': total},
    });

final _refusal = _response({
  'error': {
    'code': -32602,
    'message': 'Invalid params',
    'data': {
      'apiError': {'code': 'ERR_RCP_400', 'message': 'refused'},
    },
  },
});

void main() {
  late _MockDio mainnet;
  late _MockDio testnet;
  late SepaVirtualPayeeRepositoryImpl repository;

  setUp(() {
    mainnet = _MockDio();
    testnet = _MockDio();
    repository = SepaVirtualPayeeRepositoryImpl(
      mainnetDatasource: BullbitcoinApiSepaVirtualPayeeDatasource(
        http: mainnet,
      ),
      testnetDatasource: BullbitcoinApiSepaVirtualPayeeDatasource(
        http: testnet,
      ),
    );
  });

  void stubPages(_MockDio dio, List<Response<dynamic>> pages) {
    var call = 0;
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => pages[call++]);
  }

  List<Map<String, dynamic>> sentRequests(_MockDio dio) => verify(
    () => dio.post<dynamic>(
      any(),
      data: captureAny(named: 'data'),
      options: any(named: 'options'),
    ),
  ).captured.cast<Map<String, dynamic>>();

  group('activate', () {
    test('asks the selected environment to activate the recipient', () async {
      stubPages(testnet, [
        _response({
          'result': {'element': _payee('r-1', status: 'CREATED')},
        }),
      ]);

      final result = await repository.activate(
        recipientId: 'r-1',
        isTestnet: true,
      );

      expect(
        (result as Ok<SepaVirtualPayeeStatus, RecipientsFailure>).value,
        SepaVirtualPayeeStatus.pending,
      );
      final request = sentRequests(testnet).single;
      expect(request['method'], 'activateSepaVirtualPayee');
      expect(request['params'], {'recipientId': 'r-1'});
    });

    test('a refusal is unexpected', () async {
      stubPages(mainnet, [_refusal]);

      final result = await repository.activate(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus, RecipientsFailure>).failure,
        isA<RecipientsUnexpectedFailure>(),
      );
    });

    test('an unreachable API is a network failure', () async {
      when(
        () => mainnet.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/ak/api-recipients'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await repository.activate(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus, RecipientsFailure>).failure,
        isA<RecipientsNetworkFailure>(),
      );
    });
  });

  group('findStatus', () {
    Future<SepaVirtualPayeeStatus?> statusOf(String recipientId) async {
      final result = await repository.findStatus(
        recipientId: recipientId,
        isTestnet: false,
      );
      return (result as Ok<SepaVirtualPayeeStatus?, RecipientsFailure>).value;
    }

    test('reads the status of the recipient on the first page', () async {
      stubPages(mainnet, [
        _page([_payee('r-1'), _payee('r-2', status: 'ACTIVE')], 2),
      ]);

      expect(await statusOf('r-2'), SepaVirtualPayeeStatus.active);
    });

    test('refreshes a saved pending status from Fiat Republic', () async {
      stubPages(mainnet, [
        _page([_payee('r-1', status: 'CREATED')], 1),
        _response({
          'result': {'element': _payee('r-1', status: 'ACTIVE')},
        }),
      ]);

      expect(await statusOf('r-1'), SepaVirtualPayeeStatus.active);
      final requests = sentRequests(mainnet);
      expect(requests.map((request) => request['method']), [
        'listRecipientsFiat',
        'activateSepaVirtualPayee',
      ]);
      expect(requests.last['params'], {'recipientId': 'r-1'});
    });

    test('keeps waiting when the refreshed payee is still pending', () async {
      stubPages(mainnet, [
        _page([_payee('r-1', status: 'CREATED')], 1),
        _response({
          'result': {'element': _payee('r-1', status: 'CREATED')},
        }),
      ]);

      expect(await statusOf('r-1'), SepaVirtualPayeeStatus.pending);
    });

    test('a refused pending-status refresh is a load failure', () async {
      stubPages(mainnet, [
        _page([_payee('r-1', status: 'CREATED')], 1),
        _refusal,
      ]);

      final result = await repository.findStatus(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus?, RecipientsFailure>).failure,
        isA<RecipientsLoadFailure>(),
      );
    });

    test('finds an active recipient beyond the first page', () async {
      stubPages(mainnet, [
        _page(List.generate(50, (i) => _payee('other-$i')), 51),
        _page([_payee('r-1', status: 'ACTIVE')], 51),
      ]);

      expect(await statusOf('r-1'), SepaVirtualPayeeStatus.active);
      final pages = sentRequests(
        mainnet,
      ).map((r) => (r['params'] as Map)['paginator']).toList();
      expect(pages, [
        {'page': 1, 'pageSize': 50},
        {'page': 2, 'pageSize': 50},
      ]);
    });

    test('a recipient that is not listed is not found', () async {
      stubPages(mainnet, [
        _page([_payee('other')], 1),
      ]);

      expect(await statusOf('r-1'), isNull);
      expect(sentRequests(mainnet), hasLength(1));
    });

    test('stops after the last page it may read', () async {
      stubPages(
        mainnet,
        List.generate(
          21,
          (p) => _page(List.generate(50, (i) => _payee('other-$p-$i')), 5000),
        ),
      );

      expect(await statusOf('r-1'), isNull);
      expect(sentRequests(mainnet), hasLength(20));
    });

    test('a refusal is a load failure', () async {
      stubPages(mainnet, [_refusal]);

      final result = await repository.findStatus(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus?, RecipientsFailure>).failure,
        isA<RecipientsLoadFailure>(),
      );
    });
  });
}
