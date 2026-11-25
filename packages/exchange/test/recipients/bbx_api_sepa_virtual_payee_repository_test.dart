import 'dart:convert';
import 'dart:typed_data';

import 'package:exchange/testing.dart';
import 'package:bbx_api/bbx_api.dart' show BbxCredentialUnavailableFailure;
import 'package:exchange/exchange.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../bbx_api_test_http.dart';

/// Answers each request with the next of [bodies].
class _Answers extends FakeBbxHttp {
  final List<Object?> bodies;
  var _next = 0;

  _Answers(this.bodies);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(bodies[_next++]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, Object?> _payee(String id, {String? status}) => {
  'recipientId': id,
  'recipientTypeFiat': 'SEPA_EUR',
  'iban': 'FR7630006000011234567890189',
  'virtualPayeeStatus': ?status,
};

Map<String, Object?> _page(List<Map<String, Object?>> elements, int total) => {
  'result': {'elements': elements, 'totalElements': total},
};

Map<String, Object?> _activated(String id, String status) => {
  'result': {
    'element': {'recipientId': id, 'virtualPayeeStatus': status},
  },
};

const _refusal = {
  'error': {
    'code': -32602,
    'message': 'Invalid params for FR7630006000011234567890189',
    'data': {
      'apiError': {'code': 'ERR_RCP_400', 'message': 'refused'},
    },
  },
};

BbxApiSepaVirtualPayeeRepository _repository(
  FakeBbxHttp mainnet, [
  FakeBbxHttp? testnet,
]) => BbxApiSepaVirtualPayeeRepository(
  mainnet: mainnet.client(),
  testnet: (testnet ?? FakeBbxHttp()).client(),
);

List<(String, String, Object?)> _sent(FakeBbxHttp http) => [
  for (final r in http.requests)
    (r.path, jsonEncode(r.data), r.headers['x-api-version']),
];

T _valueOf<T>(Result<T, RecipientsFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

RecipientsFailure _failureOf<T>(Result<T, RecipientsFailure> result) =>
    switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };

void main() {
  group('activate', () {
    test('asks the selected environment', () async {
      final mainnet = FakeBbxHttp();
      final testnet = FakeBbxHttp(body: _activated('r-1', 'ACTIVE'));

      final result = await _repository(
        mainnet,
        testnet,
      ).activate(recipientId: 'r-1', isTestnet: true);

      expect(_valueOf(result), SepaVirtualPayeeStatus.active);
      expect(mainnet.requests, isEmpty);
      expect(_sent(testnet).single, (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"activateSepaVirtualPayee",'
            '"params":{"recipientId":"r-1"}}',
        '2.0.0',
      ));
    });

    test('a refusal is unexpected and keeps only the codes', () async {
      final failure = _failureOf(
        await _repository(FakeBbxHttp(body: _refusal))
            .activate(recipientId: 'r-1', isTestnet: false),
      );

      expect(failure, isA<RecipientsUnexpectedFailure>());
      expect(
        failure.logMessage,
        'BbxRpcFailure(code: -32602, apiCode: ERR_RCP_400)',
      );
    });

    test('an unreachable API is a network failure', () async {
      expect(
        _failureOf(
          await _repository(
            FakeBbxHttp(error: DioExceptionType.connectionError),
          ).activate(recipientId: 'r-1', isTestnet: false),
        ),
        isA<RecipientsNetworkFailure>(),
      );
    });

    test('no credential is not authenticated', () async {
      final http = FakeBbxHttp();
      final repository = BbxApiSepaVirtualPayeeRepository(
        mainnet: http.client(readApiKey: () async => const Ok(null)),
        testnet: FakeBbxHttp().client(),
      );

      expect(
        _failureOf(
          await repository.activate(recipientId: 'r-1', isTestnet: false),
        ),
        isA<RecipientsNotAuthenticatedFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable credential is unexpected', () async {
      final repository = BbxApiSepaVirtualPayeeRepository(
        mainnet: FakeBbxHttp().client(
          readApiKey: () async => const Err(BbxCredentialUnavailableFailure()),
        ),
        testnet: FakeBbxHttp().client(),
      );

      final failure = _failureOf(
        await repository.activate(recipientId: 'r-1', isTestnet: false),
      );

      expect(failure, isA<RecipientsUnexpectedFailure>());
      expect(failure.logMessage, 'Exchange credential unavailable');
    });
  });

  group('findStatus', () {
    Future<(SepaVirtualPayeeStatus?, List<(String, String, Object?)>)> findWith(
      String name,
      List<Object?> answers, {
      String id = 'b',
    }) async {
      final http = _Answers(answers);

      final result = await _repository(http)
          .findStatus(recipientId: id, isTestnet: false);

      final old = _oldRepository[name];
      if (old is! (List<Object?>, SepaVirtualPayeeStatus?)) {
        fail('Expected a legacy SEPA virtual payee fixture for $name');
      }
      final (oldSent, oldStatus) = old;
      expect(_sent(http), oldSent);
      expect(_valueOf(result), oldStatus);
      return (_valueOf(result), _sent(http));
    }

    test('reads the status of the recipient on the first page', () async {
      final (status, sent) = await findWith(
        'reads the status of the recipient on the first page',
        [
          _page([_payee('a'), _payee('b', status: 'ACTIVE')], 2),
        ],
      );

      expect(status, SepaVirtualPayeeStatus.active);
      expect(sent.single, (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":'
            '{"paginator":{"page":1,"pageSize":50},"filters":'
            '{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ));
    });

    test('a recipient without a virtual payee is absent', () async {
      final (status, _) = await findWith(
        'a recipient without a virtual payee is absent',
        [
          _page([_payee('b')], 1),
        ],
      );

      expect(status, SepaVirtualPayeeStatus.absent);
    });

    test('refreshes a saved pending status from Fiat Republic', () async {
      final (status, sent) = await findWith(
        'refreshes a saved pending status from Fiat Republic',
        [
          _page([_payee('b', status: 'CREATED')], 1),
          _activated('b', 'ACTIVE'),
        ],
      );

      expect(status, SepaVirtualPayeeStatus.active);
      expect(sent.map((r) => jsonDecode(r.$2)['method']), [
        'listRecipientsFiat',
        'activateSepaVirtualPayee',
      ]);
    });

    test('keeps waiting when the refreshed payee is still pending', () async {
      final (status, _) = await findWith(
        'keeps waiting when the refreshed payee is still pending',
        [
          _page([_payee('b', status: 'CREATED')], 1),
          _activated('b', 'CREATED'),
        ],
      );

      expect(status, SepaVirtualPayeeStatus.pending);
    });

    test('finds an active recipient beyond the first page', () async {
      final (status, sent) = await findWith(
        'finds an active recipient beyond the first page',
        [
          _page([for (var i = 0; i < 50; i++) _payee('p$i')], 51),
          _page([_payee('b', status: 'ACTIVE')], 51),
        ],
      );

      expect(status, SepaVirtualPayeeStatus.active);
      expect(sent, hasLength(2));
    });

    test('a recipient that is not listed is not found', () async {
      final (status, sent) = await findWith(
        'a recipient that is not listed is not found',
        [
          _page([_payee('a')], 1),
        ],
      );

      expect(status, isNull);
      expect(sent, hasLength(1));
    });

    test('stops after the last page it may read', () async {
      final (status, sent) = await findWith(
        'stops after the last page it may read',
        [
          for (var i = 0; i < 20; i++)
            _page([for (var j = 0; j < 50; j++) _payee('p$i-$j')], 5000),
        ],
      );

      expect(status, isNull);
      expect(sent, hasLength(20));
    });

    test('a refused pending-status refresh is a load failure', () async {
      final result = await _repository(
        _Answers([
          _page([_payee('b', status: 'CREATED')], 1),
          _refusal,
        ]),
      ).findStatus(recipientId: 'b', isTestnet: false);

      expect(_failureOf(result), isA<RecipientsLoadFailure>());
    });

    test('a refusal is a load failure', () async {
      final result = await _repository(FakeBbxHttp(body: _refusal))
          .findStatus(recipientId: 'b', isTestnet: false);

      expect(_failureOf(result), isA<RecipientsLoadFailure>());
    });

    test('a page without its total is a load failure', () async {
      final result = await _repository(
        FakeBbxHttp(
          body: {
            'result': {
              'elements': [_payee('a')],
            },
          },
        ),
      ).findStatus(recipientId: 'b', isTestnet: false);

      expect(_failureOf(result), isA<RecipientsLoadFailure>());
    });

    test('a timeout is a network failure', () async {
      final result = await _repository(
        FakeBbxHttp(error: DioExceptionType.receiveTimeout),
      ).findStatus(recipientId: 'b', isTestnet: false);

      expect(_failureOf(result), isA<RecipientsNetworkFailure>());
    });
  });
}

/// What the removed SepaVirtualPayeeRepositoryImpl sent and found for each
/// `findStatus` case above.
final _oldRepository = <String, Object?>{
  'reads the status of the recipient on the first page': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
    ],
    SepaVirtualPayeeStatus.active,
  ),
  'a recipient without a virtual payee is absent': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
    ],
    SepaVirtualPayeeStatus.absent,
  ),
  'refreshes a saved pending status from Fiat Republic': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"activateSepaVirtualPayee","params":{"recipientId":"b"}}',
        '2.0.0',
      ),
    ],
    SepaVirtualPayeeStatus.active,
  ),
  'keeps waiting when the refreshed payee is still pending': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"activateSepaVirtualPayee","params":{"recipientId":"b"}}',
        '2.0.0',
      ),
    ],
    SepaVirtualPayeeStatus.pending,
  ),
  'finds an active recipient beyond the first page': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":2,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
    ],
    SepaVirtualPayeeStatus.active,
  ),
  'a recipient that is not listed is not found': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
    ],
    null,
  ),
  'stops after the last page it may read': (
    [
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":1,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":2,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":3,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":4,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":5,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":6,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":7,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":8,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":9,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":10,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":11,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":12,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":13,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":14,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":15,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":16,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":17,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":18,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":19,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
      (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":{"paginator":{"page":20,"pageSize":50},"filters":{"recipientTypeFiat":["SEPA_EUR"]}}}',
        '2.0.0',
      ),
    ],
    null,
  ),
};
