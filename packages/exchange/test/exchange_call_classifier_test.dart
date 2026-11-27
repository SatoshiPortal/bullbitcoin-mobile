import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/exchange_call_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'exchange_log_capture.dart';

Future<Result<R, bbx.BbxFailure>> Function() _fails<R>(
  bbx.BbxFailure failure,
) =>
    () async => Err(failure);

Future<Result<R, bbx.BbxFailure>> Function() _answers<R>(R value) =>
    () async => Ok(value);

void main() {
  group('exchangeWrite', () {
    Future<Result<int, ExchangeWriteFailure>> write(bbx.BbxFailure failure) =>
        exchangeWrite<int, int>('test', _fails(failure), (r) => r);

    test('a reply is Done with the mapped value', () async {
      final result = await exchangeWrite<int, String>(
        'test',
        _answers(7),
        (r) => '$r',
      );
      expect(
        result,
        isA<Ok<String, ExchangeWriteFailure>>().having(
          (r) => r.value,
          'v',
          '7',
        ),
      );
    });

    test('a mapping failure after success is an unknown outcome', () async {
      for (final failing in <int Function(int)>[
        (_) => throw const FormatException('date'),
        (r) => (r as Object) as String == '' ? 0 : 1,
      ]) {
        expect(
          await exchangeWrite<int, int>('test', _answers(7), failing),
          isA<Err<int, ExchangeWriteFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeWriteOutcomeUnknownFailure>(),
          ),
        );
      }
    });

    final cases = <(String, bbx.BbxFailure, Matcher)>[
      (
        'outcome unknown from bbx_api',
        const bbx.BbxOutcomeUnknownFailure('receive timeout'),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteOutcomeUnknownFailure>().having(
            (r) => r.reason,
            'reason',
            'receive timeout',
          ),
        ),
      ),
      (
        'a JSON-RPC refusal',
        const bbx.BbxRpcFailure(code: -1, apiCode: 'ERR_X', message: 'm'),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteRefusedFailure>().having(
            (r) => r.reason,
            'reason',
            const ExchangeRefusal(rpcCode: -1, apiCode: 'ERR_X'),
          ),
        ),
      ),
      (
        'an order limit refusal',
        const bbx.BbxOrderLimitFailure(
          bound: bbx.BbxOrderLimitBound.minimum,
          amount: 20,
          currency: 'CAD',
          code: -32000,
        ),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteRefusedFailure>().having(
            (r) => r.reason,
            'reason',
            const ExchangeRefusal(
              rpcCode: -32000,
              orderLimit: ExchangeOrderLimit(
                ExchangeOrderAmountBound.minimum,
                20,
                'CAD',
              ),
            ),
          ),
        ),
      ),
      (
        'an inactive Confidential SEPA payee',
        const bbx.BbxConfidentialSepaInactiveFailure(code: -32000),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteRefusedFailure>().having(
            (r) => r.reason,
            'reason',
            const ExchangeRefusal(rpcCode: -32000, payeeInactive: true),
          ),
        ),
      ),
      (
        'an HTTP 401',
        const bbx.BbxHttpFailure(401),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>(),
        ),
      ),
      (
        'an HTTP 400',
        const bbx.BbxHttpFailure(400),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteRefusedFailure>().having(
            (r) => r.reason.httpStatus,
            'status',
            400,
          ),
        ),
      ),
      (
        'no stored key',
        const bbx.BbxMissingCredentialFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.signedOut,
          ),
        ),
      ),
      (
        'an unreadable key',
        const bbx.BbxCredentialUnavailableFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.credentialUnavailable,
          ),
        ),
      ),
      (
        'a connect timeout',
        const bbx.BbxTimeoutFailure(bbx.BbxTimeoutKind.connect),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.unreachable,
          ),
        ),
      ),
      (
        'a cancel',
        const bbx.BbxRequestCancelledFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>(),
        ),
      ),
      (
        'a bad certificate',
        const bbx.BbxBadCertificateFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>(),
        ),
      ),
      (
        'a receive timeout that reached the classifier unclassified',
        const bbx.BbxTimeoutFailure(bbx.BbxTimeoutKind.receive),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteOutcomeUnknownFailure>(),
        ),
      ),
      (
        'a lost connection',
        const bbx.BbxConnectionFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteOutcomeUnknownFailure>(),
        ),
      ),
      (
        'an unreadable reply',
        const bbx.BbxResponseFormatFailure('invalid orderId'),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteOutcomeUnknownFailure>().having(
            (r) => r.reason,
            'reason',
            'invalid orderId',
          ),
        ),
      ),
    ];
    for (final (name, failure, matcher) in cases) {
      test(name, () async => expect(await write(failure), matcher));
    }
  });

  group('the request id stays in the log line', () {
    const refused = bbx.BbxRpcFailure(
      code: -32603,
      message: 'refused for jane@example.com',
      apiCode: 'ERR_ORD_500',
      requestId: '60bc664d1f3a4c0e9b7d2a5e8c1f4b3d:0',
    );
    const limit = bbx.BbxOrderLimitFailure(
      bound: bbx.BbxOrderLimitBound.maximum,
      amount: 500,
      currency: 'CAD',
      code: -32603,
      apiCode: 'ERR_ORD_LIMIT',
      requestId: 'req-7:0',
    );

    Future<String> logsOf(Future<void> Function() call) async {
      final capture = await captureExchangeLogs();
      await call();
      return (await capture.logger.readLogs()).join('\n');
    }

    test('of a refused write, with its codes and never its text', () async {
      for (final (failure, apiCode) in [
        (refused, refused.apiCode),
        (limit, limit.apiCode),
      ]) {
        final logs = await logsOf(
          () =>
              exchangeWrite<int, int>('placeOrder', _fails(failure), (r) => r),
        );
        expect(logs, contains('requestId=${failure.requestId}'));
        expect(logs, contains('apiCode: $apiCode'));
        expect(logs, isNot(contains('jane@example.com')));
      }
    });

    test('of a failed read and a failed list page', () async {
      final read = await logsOf(
        () =>
            exchangeRead<int, int>('getUserSummary', _fails(refused), (r) => r),
      );
      expect(read, contains('requestId=${refused.requestId}'));
      final list = await logsOf(
        () => exchangeList<int, int>('listOrders', _fails(refused), (r) => r),
      );
      expect(list, contains('requestId=${refused.requestId}'));
    });
  });

  group('writeNotRun', () {
    final cases = <(ExchangeFailure, Matcher)>[
      (
        const ExchangeNotAuthenticatedFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.signedOut,
          ),
        ),
      ),
      (
        const ExchangeCredentialReadFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.credentialUnavailable,
          ),
        ),
      ),
      (
        const ExchangeOperationStaleFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.sessionChanged,
          ),
        ),
      ),
      (
        const ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>(),
        ),
      ),
      (
        const ExchangeUnsupportedNetworkFailure(),
        isA<Err<int, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>().having(
            (r) => r.reason,
            'reason',
            ExchangeNotSentReason.unreachable,
          ),
        ),
      ),
    ];
    for (final (failure, matcher) in cases) {
      test('${failure.runtimeType}', () {
        expect(writeNotRun<int>(failure), matcher);
      });
    }
  });

  group('exchangeRead', () {
    Future<Result<int, ExchangeReadFailure>> read(bbx.BbxFailure failure) =>
        exchangeRead<int, int>('test', _fails(failure), (r) => r);

    test('a reply is Got', () async {
      expect(
        await exchangeRead<int, int>('test', _answers<int?>(3), (r) => r),
        isA<Ok<int, ExchangeReadFailure>>().having((r) => r.value, 'v', 3),
      );
    });

    test('no reply is Missing, never a failure', () async {
      expect(
        await exchangeRead<int, int>('test', _answers<int?>(null), (r) => r),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeMissingFailure>(),
        ),
      );
    });

    test('a reply that cannot be mapped is Malformed, not a throw', () async {
      expect(
        await exchangeRead<int, int>(
          'test',
          _answers<int?>(3),
          (_) => throw StateError('x'),
        ),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeMalformedFailure>(),
        ),
      );
    });

    final cases = <(String, bbx.BbxFailure, Matcher)>[
      (
        'an HTTP 401',
        const bbx.BbxHttpFailure(401),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>().having(
            (r) => r.why,
            'why',
            ExchangeSessionRejection.server,
          ),
        ),
      ),
      (
        'no stored key',
        const bbx.BbxMissingCredentialFailure(),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>().having(
            (r) => r.why,
            'why',
            ExchangeSessionRejection.signedOut,
          ),
        ),
      ),
      (
        'an unreadable key',
        const bbx.BbxCredentialUnavailableFailure(),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>().having(
            (r) => r.why,
            'why',
            ExchangeSessionRejection.credentialUnavailable,
          ),
        ),
      ),
      (
        'a timeout',
        const bbx.BbxTimeoutFailure(bbx.BbxTimeoutKind.receive),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeUnreachableFailure>().having(
            (r) => r.isNetwork,
            'isNetwork',
            isTrue,
          ),
        ),
      ),
      (
        'a JSON-RPC error',
        const bbx.BbxRpcFailure(code: -1, message: 'account 12'),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeUnreachableFailure>()
              .having((r) => r.isNetwork, 'isNetwork', isFalse)
              .having((r) => r.reason, 'reason', isNot(contains('account'))),
        ),
      ),
      (
        'an HTTP 503',
        const bbx.BbxHttpFailure(503),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeUnreachableFailure>(),
        ),
      ),
      (
        'an unreadable reply',
        const bbx.BbxResponseFormatFailure('invalid userNumber'),
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeMalformedFailure>(),
        ),
      ),
    ];
    for (final (name, failure, matcher) in cases) {
      test(name, () async => expect(await read(failure), matcher));
    }
  });

  group('exchangeList', () {
    test('a page keeps its items and the next page', () async {
      expect(
        await exchangeList<int, String>(
          'test',
          _answers((items: [1, 2], next: 2)),
          (r) => '$r',
        ),
        isA<Ok<ExchangePage<String>, ExchangeListFailure>>()
            .having((r) => r.value.items, 'items', ['1', '2'])
            .having((r) => r.value.next, 'next', 2),
      );
    });

    test('a failure is never an empty page', () async {
      for (final failure in <bbx.BbxFailure>[
        const bbx.BbxConnectionFailure(),
        const bbx.BbxResponseFormatFailure('elements'),
        const bbx.BbxHttpFailure(500),
      ]) {
        expect(
          await exchangeList<int, int>('test', _fails(failure), (r) => r),
          isA<Err<ExchangePage<int>, ExchangeListFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeUnreachableFailure>(),
          ),
        );
      }
    });

    test('a 401 is a rejected session', () async {
      expect(
        await exchangeList<int, int>(
          'test',
          _fails(const bbx.BbxHttpFailure(401)),
          (r) => r,
        ),
        isA<Err<ExchangePage<int>, ExchangeListFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>(),
        ),
      );
    });

    test('an item that cannot be mapped fails the page', () async {
      expect(
        await exchangeList<int, int>(
          'test',
          _answers((items: [1], next: null)),
          (_) => throw const FormatException('x'),
        ),
        isA<Err<ExchangePage<int>, ExchangeListFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeUnreachableFailure>(),
        ),
      );
    });
  });
}
