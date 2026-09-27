import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/user_preference_payload_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

const _usersPath = '/ak/api-users';

Response<dynamic> _response(dynamic body, {int status = 200}) => Response(
  requestOptions: RequestOptions(path: _usersPath),
  statusCode: status,
  data: body,
);

void main() {
  late _MockDio dio;
  late BullbitcoinApiDatasource datasource;

  setUp(() {
    dio = _MockDio();
    datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);
  });

  void stub(dynamic body, {int status = 200}) {
    when(
      () => dio.post<dynamic>(
        _usersPath,
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response(body, status: status));
  }

  Future<void> save() => datasource.saveUserPreference(
    apiKey: 'key',
    params: UserPreferencePayloadModel(autoBuyEnabled: 'true'),
  );

  group('BullbitcoinApiDatasource.saveUserPreference', () {
    test('accepts a result payload', () async {
      stub({
        'result': {'element': <String, dynamic>{}},
      });

      await expectLater(save(), completes);
    });

    test('rejects a JSON-RPC error returned with HTTP 200', () async {
      stub({
        'error': {'code': -32000, 'message': 'User preferences not saved'},
      });

      await expectLater(
        save(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('User preferences not saved'),
          ),
        ),
      );
    });

    test('rejects a non-200 response', () async {
      stub(<String, dynamic>{}, status: 500);

      await expectLater(save(), throwsA(isA<Exception>()));
    });

    test('rejects a non-map response body', () async {
      stub('unexpected response');

      await expectLater(save(), throwsA(isA<Exception>()));
    });
  });
}
