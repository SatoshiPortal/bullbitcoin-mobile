import 'dart:async';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

/// Fails every request with [type], as a dropped connection or a timeout does.
class FailingHttp implements HttpClientAdapter {
  final DioExceptionType type;
  final List<RequestOptions> requests = [];

  FailingHttp(this.type);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

/// Fails every request with an [Error], as a bug in a plugin would.
class FailingHttpWithError implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError('bug');

  @override
  void close({bool force = false}) {}
}

/// The failure of one `getUserSummary` request over [http].
Future<BbxFailure> summaryFailure(
  HttpClientAdapter http, {
  Future<Result<String?, BbxFailure>> Function()? readActiveApiKey,
}) => failedCall(
  bbx(http, readActiveApiKey: readActiveApiKey).users.getUserSummary(),
);

void main() {
  test('open shares the credential reader with notifications', () async {
    var credentialReads = 0;
    final api = Bbx.open(
      endpoint: 'https://example.invalid',
      readActiveApiKey: () async {
        credentialReads++;
        return const Ok(null);
      },
    );
    addTearDown(api.notifications.dispose);

    expect(
      await failedCall(api.users.getUserSummary()),
      isA<BbxMissingCredentialFailure>(),
    );
    expect(await api.notifications.connect(), isA<Ok<void, BbxFailure>>());
    expect(api.notifications.isConnected, isFalse);
    expect(credentialReads, 2);
  });

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

    test('a JSON-RPC error that is not an object keeps no code', () async {
      expect(
        await summaryFailure(FakeHttp(body: {'error': 'nope'})),
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', isNull)
            .having((f) => f.message, 'message', isNull)
            .having((f) => f.apiCode, 'apiCode', isNull),
      );
    });

    test('keeps an ERR_ apiError code and drops any other', () async {
      expect(
        await summaryFailure(
          FakeHttp(
            body: {
              'error': {
                'code': -32603,
                'data': {
                  'apiError': {'code': 'ERR_RCP_PO404'},
                },
              },
            },
          ),
        ),
        isA<BbxRpcFailure>().having(
          (f) => f.apiCode,
          'apiCode',
          'ERR_RCP_PO404',
        ),
      );

      expect(
        await summaryFailure(
          FakeHttp(
            body: {
              'error': {
                'code': -32603,
                'data': {
                  'apiError': {'code': 'account 1234'},
                },
              },
            },
          ),
        ),
        isA<BbxRpcFailure>().having((f) => f.apiCode, 'apiCode', isNull),
      );
    });

    test('keeps the server request id and drops free text', () async {
      const requestId = '60bc664d1f3a4c0e9b7d2a5e8c1f4b3d:0';
      final failure = await summaryFailure(
        FakeHttp(
          body: {
            'error': {
              'code': -32603,
              'message': 'refused for jane@example.com',
              'data': {
                'apiError': {'code': 'ERR_ORD_500', 'requestId': requestId},
              },
            },
          },
        ),
      );
      expect(
        failure,
        isA<BbxRpcFailure>().having((f) => f.requestId, 'requestId', requestId),
      );
      expect(
        failure.toString(),
        'BbxRpcFailure(code: -32603, apiCode: ERR_ORD_500, '
        'requestId=$requestId)',
      );

      expect(
        await summaryFailure(
          FakeHttp(
            body: {
              'error': {
                'code': -32603,
                'data': {'requestId': 'req-7:0'},
              },
            },
          ),
        ),
        isA<BbxRpcFailure>().having((f) => f.requestId, 'requestId', 'req-7:0'),
      );

      final unlabelled = await summaryFailure(
        FakeHttp(
          body: {
            'error': {
              'code': -32603,
              'data': {
                'apiError': {'requestId': 'order for jane@example.com'},
              },
            },
          },
        ),
      );
      expect(unlabelled.requestId, isNull);
      expect('$unlabelled', isNot(contains('requestId')));
    });

    test('every refusal describes its codes and request id', () {
      const requestId = 'req-7:0';
      expect(
        const BbxOrderLimitFailure(
          bound: BbxOrderLimitBound.minimum,
          amount: 20,
          currency: 'CAD',
          code: -32603,
          apiCode: 'ERR_ORD_LIMIT',
          requestId: requestId,
        ).toString(),
        'BbxOrderLimitFailure(bound: minimum, amount: 20.0, currency: CAD, '
        'code: -32603, apiCode: ERR_ORD_LIMIT, requestId=$requestId)',
      );
      expect(
        const BbxConfidentialSepaInactiveFailure(
          code: -32603,
          apiCode: 'ERR_ORD_CSRCP400',
          requestId: requestId,
        ).toString(),
        'BbxConfidentialSepaInactiveFailure(code: -32603, '
        'apiCode: ERR_ORD_CSRCP400, requestId=$requestId)',
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

    for (final (name, type) in [
      ('connectionTimeout', DioExceptionType.connectionTimeout),
      ('sendTimeout', DioExceptionType.sendTimeout),
      ('receiveTimeout', DioExceptionType.receiveTimeout),
    ]) {
      test('$name is a timeout failure', () async {
        expect(
          await summaryFailure(FailingHttp(type)),
          isA<BbxTimeoutFailure>(),
        );
      });
    }

    for (final (name, type, kind) in [
      (
        'connection',
        DioExceptionType.connectionTimeout,
        BbxTimeoutKind.connect,
      ),
      ('send', DioExceptionType.sendTimeout, BbxTimeoutKind.send),
      ('receive', DioExceptionType.receiveTimeout, BbxTimeoutKind.receive),
    ]) {
      test('a $name timeout reports its phase', () async {
        expect(
          await summaryFailure(FailingHttp(type)),
          isA<BbxTimeoutFailure>()
              .having((f) => f.kind, 'kind', kind)
              .having((f) => '$f', 'toString', contains('kind: ${kind.name}')),
        );
      });
    }

    for (final (name, type, check) in [
      (
        'connectionError',
        DioExceptionType.connectionError,
        (BbxFailure f) => f is BbxConnectionFailure,
      ),
      (
        'badCertificate',
        DioExceptionType.badCertificate,
        (BbxFailure f) => f is BbxBadCertificateFailure,
      ),
      (
        'cancel',
        DioExceptionType.cancel,
        (BbxFailure f) => f is BbxRequestCancelledFailure,
      ),
      (
        'transformTimeout',
        DioExceptionType.transformTimeout,
        (BbxFailure f) => f is BbxTransformTimeoutFailure,
      ),
      (
        'unknown',
        DioExceptionType.unknown,
        (BbxFailure f) => f is BbxTransportFailure,
      ),
    ]) {
      test('$name maps to its own failure', () async {
        final failure = await summaryFailure(FailingHttp(type));
        expect(check(failure), isTrue, reason: '$failure');
      });
    }

    test(
      'a transport failure retains its package origin, not its text',
      () async {
        final failure = await summaryFailure(
          FailingHttp(DioExceptionType.connectionError),
        );
        expect(failure, isA<BbxConnectionFailure>());
        expect(failure.origin?.toString(), contains('package:bbx_api/'));
        expect('$failure', isNot(contains('package:bbx_api/')));
      },
    );

    test(
      'an RPC refusal retains its package origin, not the server text',
      () async {
        final failure = await summaryFailure(
          FakeHttp(
            body: {
              'error': {
                'code': -32000,
                'message': 'SYNTHETIC_PRIVATE_RPC_MESSAGE',
              },
            },
          ),
        );
        expect(failure, isA<BbxRpcFailure>());
        expect(failure.origin?.toString(), contains('package:bbx_api/'));
        expect('$failure', isNot(contains('SYNTHETIC_PRIVATE_RPC_MESSAGE')));
        expect('$failure', isNot(contains('package:bbx_api/')));
      },
    );

    test(
      'a format failure retains its package origin without a response quote',
      () async {
        final failure = await summaryFailure(
          FakeHttp(body: ['SYNTHETIC_PRIVATE_RESPONSE']),
        );
        expect(failure, isA<BbxResponseFormatFailure>());
        expect(failure.origin?.toString(), contains('package:bbx_api/'));
        expect('$failure', isNot(contains('SYNTHETIC_PRIVATE_RESPONSE')));
        expect('$failure', isNot(contains('package:bbx_api/')));
      },
    );

    test('request failures retain the private origin, not its text', () async {
      final failures = <BbxFailure>[
        await summaryFailure(FailingHttp(DioExceptionType.connectionError)),
        await summaryFailure(FakeHttp(status: 500, body: {})),
        await summaryFailure(
          FakeHttp(
            body: {
              'error': {'code': -1, 'message': 'SYNTHETIC_PRIVATE_PAYLOAD'},
            },
          ),
        ),
        await summaryFailure(FakeHttp(body: [])),
      ];

      for (final failure in failures) {
        expect(
          failure.origin.toString(),
          contains('package:bbx_api/'),
          reason: '${failure.runtimeType} needs its original frames',
        );
        expect('$failure', isNot(contains('SYNTHETIC_PRIVATE_PAYLOAD')));
      }
    });

    test('an Error from inside the transport propagates', () async {
      await expectLater(
        bbx(FailingHttpWithError()).users.getUserSummary(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('credential', () {
    test('no key is a missing credential failure and sends nothing', () async {
      final http = FakeHttp(body: {'result': null});

      expect(
        await summaryFailure(http, readActiveApiKey: () => okApiKey(null)),
        isA<BbxMissingCredentialFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable credential is unavailable and sends nothing', () async {
      final http = FakeHttp(body: {'result': null});

      expect(
        await summaryFailure(http, readActiveApiKey: failedApiKey),
        isA<BbxCredentialUnavailableFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('a credential read that throws an Exception is unavailable', () async {
      final http = FakeHttp(body: {'result': null});

      expect(
        await summaryFailure(
          http,
          readActiveApiKey: () async => throw Exception('storage'),
        ),
        isA<BbxCredentialUnavailableFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('a credential read that throws an Error propagates', () async {
      final http = FakeHttp(body: {'result': null});

      await expectLater(
        bbx(
          http,
          readActiveApiKey: () async => throw StateError('bug'),
        ).users.getUserSummary(),
        throwsA(isA<StateError>()),
      );
      expect(http.requests, isEmpty);
    });

    test(
      'reads the credential once per request and sends the new key',
      () async {
        final http = FakeHttp(
          body: {
            'result': {'ownerName': 'Ada'},
          },
        );
        var reads = 0;
        final api = bbx(
          http,
          readActiveApiKey: () async {
            reads++;
            return Ok<String?, BbxFailure>('key-$reads');
          },
        );

        await api.recipients.checkSinpe(phoneNumber: '1');
        await api.recipients.checkSinpe(phoneNumber: '2');

        expect(reads, 2);
        expect(
          [for (final request in http.requests) request.headers['X-API-Key']],
          ['key-1', 'key-2'],
        );
      },
    );

    test('a credential that fails stops the next request', () async {
      final http = FakeHttp(
        body: {
          'result': {'ownerName': 'Ada'},
        },
      );
      var reads = 0;
      final api = bbx(
        http,
        readActiveApiKey: () async {
          reads++;
          return reads == 1
              ? Ok<String?, BbxFailure>('key')
              : const Err(BbxCredentialUnavailableFailure());
        },
      );

      expect(valueOf(await api.recipients.checkSinpe(phoneNumber: '1')), 'Ada');
      expect(
        await failedCall(api.recipients.checkSinpe(phoneNumber: '2')),
        isA<BbxCredentialUnavailableFailure>(),
      );
      expect(http.requests, hasLength(1));
    });
  });

  group('session rejection', () {
    test('a 401 marks the client as rejected', () async {
      final client = bbx(FakeHttp(status: 401, body: {'result': null}));
      expect(client.sessionRejected, isFalse);

      await client.users.getUserSummary();

      expect(client.sessionRejected, isTrue);
    });

    test('a 401 to a write marks it too', () async {
      final client = bbx(FakeHttp(status: 401, body: {'result': null}));

      await client.users.saveUserPreferences(
        const UserPreferences(language: 'en'),
      );

      expect(client.sessionRejected, isTrue);
    });

    test('another refusal does not', () async {
      final client = bbx(FakeHttp(status: 403, body: {'result': null}));

      await client.users.getUserSummary();

      expect(client.sessionRejected, isFalse);
    });

    test('a request that was not sent does not', () async {
      final http = FakeHttp(status: 401, body: {'result': null});
      final client = bbx(http, readActiveApiKey: () => okApiKey(null));

      await client.users.getUserSummary();

      expect(http.requests, isEmpty);
      expect(client.sessionRejected, isFalse);
    });
  });

  group('timeouts', () {
    test('no timeout by default', () async {
      final http = FakeHttp(body: {'result': null});

      await bbx(http).users.getUserSummary();

      final request = http.requests.single;
      expect(request.connectTimeout, isNull);
      expect(request.sendTimeout, isNull);
      expect(request.receiveTimeout, isNull);
    });

    test('the standard timeouts reach the request', () async {
      final http = FakeHttp(body: {'result': null});

      await bbx(http, timeouts: BbxTimeouts.standard).users.getUserSummary();

      final request = http.requests.single;
      expect(request.connectTimeout, const Duration(seconds: 30));
      expect(request.sendTimeout, const Duration(seconds: 30));
      expect(request.receiveTimeout, const Duration(seconds: 30));
    });

    test('each phase keeps its own duration', () async {
      final http = FakeHttp(body: {'result': null});

      await bbx(
        http,
        timeouts: const BbxTimeouts(
          connect: Duration(seconds: 1),
          receive: Duration(seconds: 2),
        ),
      ).users.getUserSummary();

      final request = http.requests.single;
      expect(request.connectTimeout, const Duration(seconds: 1));
      expect(request.sendTimeout, isNull);
      expect(request.receiveTimeout, const Duration(seconds: 2));
    });
  });

  group('write', () {
    Future<BbxFailure> writeFailureOver(
      HttpClientAdapter http, {
      Future<Result<String?, BbxFailure>> Function()? readActiveApiKey,
    }) => failedCall(
      bbx(
        http,
        readActiveApiKey: readActiveApiKey,
      ).users.saveUserPreferences(const UserPreferences(language: 'en')),
    );

    for (final type in [
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.transformTimeout,
      DioExceptionType.unknown,
    ]) {
      test('${type.name} after sending is an unknown outcome', () async {
        expect(
          await writeFailureOver(FailingHttp(type)),
          isA<BbxOutcomeUnknownFailure>(),
        );
      });
    }

    for (final (type, check) in [
      (
        DioExceptionType.connectionTimeout,
        (BbxFailure f) =>
            f is BbxTimeoutFailure && f.kind == BbxTimeoutKind.connect,
      ),
      (
        DioExceptionType.badCertificate,
        (BbxFailure f) => f is BbxBadCertificateFailure,
      ),
      (
        DioExceptionType.cancel,
        (BbxFailure f) => f is BbxRequestCancelledFailure,
      ),
    ]) {
      test('${type.name} happens before sending and stays as it is', () async {
        final failure = await writeFailureOver(FailingHttp(type));
        expect(check(failure), isTrue, reason: '$failure');
      });
    }

    for (final status in [204, 302, 502, 504]) {
      test('status $status is an unknown outcome', () async {
        expect(
          await writeFailureOver(
            FakeHttp(status: status, body: {'result': null}),
          ),
          isA<BbxOutcomeUnknownFailure>().having(
            (f) => f.reason,
            'reason',
            'status $status',
          ),
        );
      });
    }

    for (final status in [400, 401, 403, 500, 503]) {
      test("status $status is the server's refusal", () async {
        expect(
          await writeFailureOver(
            FakeHttp(status: status, body: {'result': null}),
          ),
          isA<BbxHttpFailure>().having((f) => f.status, 'status', status),
        );
      });
    }

    test('a reply that cannot be read is an unknown outcome', () async {
      expect(
        await failedCall(
          bbx(FakeHttp(body: {'result': 'x'})).recipients.createMyRecipient(
            recipientType: 'OUT_BITCOIN_ADDRESS',
            address: 'bc1q',
            isOwner: true,
            isDefault: true,
          ),
        ),
        isA<BbxOutcomeUnknownFailure>(),
      );
    });

    test('a JSON-RPC error is a refusal', () async {
      expect(
        await writeFailureOver(
          FakeHttp(
            body: {
              'error': {'code': -32000, 'message': 'no'},
            },
          ),
        ),
        isA<BbxRpcFailure>().having((f) => f.code, 'code', -32000),
      );
    });

    test('a missing credential never sends the write', () async {
      final http = FakeHttp(body: {'result': null});
      expect(
        await writeFailureOver(http, readActiveApiKey: () => okApiKey(null)),
        isA<BbxMissingCredentialFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('the outcome text names the failure, not the payload', () async {
      final failure = await writeFailureOver(
        FailingHttp(DioExceptionType.receiveTimeout),
      );
      expect('$failure', 'BbxOutcomeUnknownFailure(receive timeout)');
    });
  });
}
