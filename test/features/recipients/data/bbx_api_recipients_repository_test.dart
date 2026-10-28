import 'dart:convert';
import 'dart:typed_data';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/bbx_api_recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details_input.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';

class _Api implements dio.HttpClientAdapter {
  Object? answer;
  final List<dio.RequestOptions> requests = [];
  Map<String, dynamic> get lastPayload =>
      requests.last.data as Map<String, dynamic>;
  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final answer = this.answer;
    if (answer is dio.DioExceptionType) {
      throw dio.DioException(requestOptions: options, type: answer);
    }
    return dio.ResponseBody.fromString(
      jsonEncode(answer),
      200,
      headers: {
        dio.Headers.contentTypeHeader: [dio.Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _result(Map<String, dynamic> result) => {
  'jsonrpc': '2.0',
  'id': '1',
  'result': result,
};

Map<String, dynamic> _sepa(
  String id, {
  bool isOwner = true,
  bool isCorporate = false,
  String? virtualPayeeStatus,
}) => {
  'recipientId': id,
  'userId': 'user-1',
  'userNbr': 1,
  'isArchived': false,
  'createdAt': '2026-10-01T00:00:00.000Z',
  'updatedAt': '2026-10-01T00:00:00.000Z',
  'recipientTypeFiat': 'SEPA_EUR',
  'isOwner': isOwner,
  'iban': 'FR7630006000011234567890189',
  'isCorporate': isCorporate,
  if (isCorporate) 'corporateName': 'Example Corp',
  if (!isCorporate) 'firstname': 'Test',
  if (!isCorporate) 'lastname': 'User',
  'virtualPayeeStatus': ?virtualPayeeStatus,
};

void main() {
  late _Api api;
  late BbxApiRecipientsRepository repository;

  setUp(() {
    api = _Api();
    final client = bbx.BBApiClient(
      bbx.ApiConfig('https://api.test', clientSource: 'Test App'),
      initialDio: dio.Dio()..httpClientAdapter = api,
    );
    repository = BbxApiRecipientsRepository(
      api: BbxApiDatasource(bbx.BbxApi(client.apiConfig, client: client)),
    );
  });

  Map<String, dynamic> lastParams() =>
      api.lastPayload['params'] as Map<String, dynamic>;

  group('listRecipients', () {
    Future<List<(String, RecipientType)>> rows(
      List<RecipientType>? recipientTypes,
    ) async {
      final result = await repository.listRecipients(
        isTestnet: true,
        recipientTypes: recipientTypes,
      );
      return switch (result) {
        Ok(:final value) => [
          for (final r in value.recipients) (r.recipientId, r.type),
        ],
        Err() => fail('expected a recipient list'),
      };
    }

    void stubList(List<Map<String, dynamic>> elements) => api.answer = _result({
      'elements': elements,
      'totalElements': elements.length,
    });

    test('sends the method, paginator and filters', () async {
      stubList([]);

      await repository.listRecipients(
        isTestnet: true,
        page: 2,
        pageSize: 10,
        recipientTypes: [
          RecipientType.sepaEur,
          RecipientType.confidentialSepaEur,
          RecipientType.interacEmailCad,
        ],
        isOwner: true,
        search: 'x',
      );

      expect(api.lastPayload['method'], 'listRecipientsFiat');
      expect(api.requests.last.headers['x-api-version'], '2.0.0');
      expect(lastParams(), {
        'paginator': {'page': 2, 'pageSize': 10},
        'filters': {
          'recipientTypeFiat': ['SEPA_EUR', 'INTERAC_EMAIL_CAD'],
          'isOwner': true,
          'search': 'x',
        },
      });
    });

    test('sends no filters when none are set', () async {
      stubList([]);

      await repository.listRecipients(isTestnet: true, fiatOnly: false);

      expect(api.lastPayload['method'], 'listRecipients');
      expect(lastParams(), {
        'paginator': {'page': 1, 'pageSize': 50},
      });
    });

    test('parses with the app model and skips unreadable rows', () async {
      api.answer = _result({
        'elements': [
          _sepa('a'),
          {..._sepa('b'), 'recipientTypeFiat': 'SOMETHING_NEW'},
          _sepa('c'),
        ],
        'totalElements': 3,
      });

      final result = await repository.listRecipients(isTestnet: true);

      final value =
          (result as Ok).value
              as ({List<dynamic> recipients, int totalRecipients});
      expect(value.recipients.map((r) => r.recipientId), ['a', 'c']);
      expect(value.totalRecipients, 3);
      expect(value.recipients.first.details, isA<SepaEurDetails>());
    });

    test('a list of all types shows each SEPA recipient once', () async {
      stubList([_sepa('a', virtualPayeeStatus: 'ACTIVE'), _sepa('b')]);

      expect(await rows(null), [
        ('a', RecipientType.sepaEur),
        ('b', RecipientType.sepaEur),
      ]);
    });

    test('a Confidential SEPA list shows the confidential rows', () async {
      stubList([
        _sepa('active', virtualPayeeStatus: 'ACTIVE'),
        _sepa('pending', virtualPayeeStatus: 'CREATED'),
        _sepa('eligible'),
        _sepa('corporate', isCorporate: true),
        _sepa('other', isOwner: false),
      ]);

      expect(await rows([RecipientType.confidentialSepaEur]), [
        ('active', RecipientType.confidentialSepaEur),
        ('pending', RecipientType.confidentialSepaEur),
        ('eligible', RecipientType.confidentialSepaEur),
      ]);
    });

    test('an API error is the load failure', () async {
      api.answer = {
        'error': {'code': -32602, 'message': 'invalid'},
      };

      expect(
        await repository.listRecipients(isTestnet: true),
        isA<Err>().having((e) => e.failure, 'f', isA<RecipientsLoadFailure>()),
      );
    });

    test('a timeout is the network failure', () async {
      api.answer = dio.DioExceptionType.connectionTimeout;

      expect(
        await repository.listRecipients(isTestnet: true),
        isA<Err>().having(
          (e) => e.failure,
          'f',
          isA<RecipientsNetworkFailure>(),
        ),
      );
    });
  });

  group('saveRecipient', () {
    final RecipientDetails details = const RecipientDetailsInput(
      recipientType: RecipientType.sinpeMovilCrc,
      phoneNumber: '8888-8888',
      ownerName: 'Test User',
    ).toDomain();

    test('sends the app model and parses the saved recipient', () async {
      api.answer = _result({
        'element': {
          'recipientId': 'r1',
          'userId': 'user-1',
          'userNbr': 1,
          'isArchived': false,
          'createdAt': '2026-10-01T00:00:00.000Z',
          'updatedAt': '2026-10-01T00:00:00.000Z',
          'recipientTypeFiat': 'SINPE_MOVIL_CRC',
          'phoneNumber': '8888-8888',
          'ownerName': 'Test User',
        },
      });

      final result = await repository.saveRecipient(details, isTestnet: true);

      expect(api.lastPayload['method'], 'createRecipientFiat');
      expect(
        (lastParams()['element'] as Map)['recipientTypeFiat'],
        'SINPE_MOVIL_CRC',
      );
      final saved = (result as Ok).value;
      expect(saved.recipientId, 'r1');
      expect(saved.details, isA<SinpeMovilCrcDetails>());
    });

    test('an API error is the save failure', () async {
      api.answer = {
        'error': {'code': -32602, 'message': 'invalid'},
      };

      expect(
        await repository.saveRecipient(details, isTestnet: true),
        isA<Err>().having((e) => e.failure, 'f', isA<RecipientsSaveFailure>()),
      );
    });
  });

  group('listCadBillers', () {
    test('a search shorter than 3 characters fails without a call', () async {
      expect(
        await repository.listCadBillers(searchTerm: 'ab', isTestnet: true),
        isA<Err>().having(
          (e) => e.failure,
          'f',
          isA<RecipientsCadBillerSearchFailure>(),
        ),
      );
      expect(api.requests, isEmpty);
    });

    test('a longer search returns the billers', () async {
      api.answer = _result({
        'elements': [
          {'payeeCode': '0001', 'payeeName': 'Example Hydro'},
          {'payeeName': 'No code'},
        ],
        'totalElements': 2,
      });

      final result = await repository.listCadBillers(
        searchTerm: 'hyd',
        isTestnet: true,
      );

      expect((result as Ok).value.map((b) => b.payeeCode), ['0001']);
    });
  });
}
