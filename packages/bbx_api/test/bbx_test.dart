import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

Future<BbxFailure> summaryFailure(FakeHttp http) =>
    failedCall(bbx(http).users.getUserSummary());

void main() {
  group('request', () {
    test('sends the JSON-RPC envelope with the API key', () async {
      final http = FakeHttp(
        body: {
          'result': {'success': true},
        },
      );

      expect(
        valueOf(await bbx(http).users.registerResponsibilityConsent()),
        isTrue,
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-users');
      expect(request.method, 'POST');
      expect(request.data, {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'registerResponsibilityConsent',
        'params': <String, Object?>{},
      });
      expect(request.headers['X-API-Key'], 'test-key');
    });

    test('a JSON-RPC error keeps its code and message', () async {
      final failure = await summaryFailure(
        FakeHttp(
          body: {
            'error': {'code': -32000, 'message': 'nope'},
          },
        ),
      );

      expect(
        failure,
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', -32000)
            .having((f) => f.message, 'message', 'nope')
            .having((f) => f.apiCode, 'apiCode', isNull)
            .having((f) => '$f', 'toString', isNot(contains('nope'))),
      );
    });

    test('a body that is not an object is a format failure', () async {
      expect(
        await summaryFailure(FakeHttp(body: [1, 2])),
        isA<BbxResponseFormatFailure>().having(
          (f) => f.reason,
          'reason',
          'response is not a JSON object',
        ),
      );
    });

    test('a non-200 success status is an HTTP failure', () async {
      expect(
        await summaryFailure(FakeHttp(status: 204, body: {})),
        isA<BbxHttpFailure>()
            .having((f) => f.status, 'status', 204)
            .having((f) => '$f', 'toString', contains('204')),
      );
    });

    test('a refused status is an HTTP failure, not a transport one', () async {
      expect(
        await summaryFailure(FakeHttp(status: 500, body: {})),
        isA<BbxHttpFailure>().having((f) => f.status, 'status', 500),
      );
    });
  });
}
