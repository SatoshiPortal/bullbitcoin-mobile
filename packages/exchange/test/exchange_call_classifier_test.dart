import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/exchange_call_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<Result<R, bbx.BbxFailure>> Function() _fails<R>(
  bbx.BbxFailure failure,
) =>
    () async => Err(failure);

Future<Result<R, bbx.BbxFailure>> Function() _answers<R>(R value) =>
    () async => Ok(value);

void main() {
  group('exchangeWrite', () {
    Future<ExchangeWrite<int>> write(bbx.BbxFailure failure) =>
        exchangeWrite<int, int>('test', _fails(failure), (r) => r);

    test('a reply is Done with the mapped value', () async {
      final result = await exchangeWrite<int, String>(
        'test',
        _answers(7),
        (r) => '$r',
      );
      expect(result, isA<WriteDone<String>>().having((r) => r.value, 'v', '7'));
    });

    test('a mapping failure after success is an unknown outcome', () async {
      for (final failing in <int Function(int)>[
        (_) => throw const FormatException('date'),
        (r) => (r as Object) as String == '' ? 0 : 1,
      ]) {
        expect(
          await exchangeWrite<int, int>('test', _answers(7), failing),
          isA<WriteOutcomeUnknown<int>>(),
        );
      }
    });

    final cases = <(String, bbx.BbxFailure, Matcher)>[
      (
        'outcome unknown from bbx_api',
        const bbx.BbxOutcomeUnknownFailure('receive timeout'),
        isA<WriteOutcomeUnknown<int>>().having(
          (r) => r.reason,
          'reason',
          'receive timeout',
        ),
      ),
      (
        'a JSON-RPC refusal',
        const bbx.BbxRpcFailure(code: -1, apiCode: 'ERR_X', message: 'm'),
        isA<WriteRefused<int>>().having(
          (r) => r.reason,
          'reason',
          const ExchangeRefusal(rpcCode: -1, apiCode: 'ERR_X'),
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
        isA<WriteRefused<int>>().having(
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
      (
        'an inactive Confidential SEPA payee',
        const bbx.BbxConfidentialSepaInactiveFailure(code: -32000),
        isA<WriteRefused<int>>().having(
          (r) => r.reason,
          'reason',
          const ExchangeRefusal(rpcCode: -32000, payeeInactive: true),
        ),
      ),
      (
        'an HTTP 401',
        const bbx.BbxHttpFailure(401),
        isA<WriteSessionRejected<int>>(),
      ),
      (
        'an HTTP 400',
        const bbx.BbxHttpFailure(400),
        isA<WriteRefused<int>>().having(
          (r) => r.reason.httpStatus,
          'status',
          400,
        ),
      ),
      (
        'no stored key',
        const bbx.BbxMissingCredentialFailure(),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.signedOut,
        ),
      ),
      (
        'an unreadable key',
        const bbx.BbxCredentialUnavailableFailure(),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.credentialUnavailable,
        ),
      ),
      (
        'a connect timeout',
        const bbx.BbxTimeoutFailure(bbx.BbxTimeoutKind.connect),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.unreachable,
        ),
      ),
      (
        'a cancel',
        const bbx.BbxRequestCancelledFailure(),
        isA<WriteNotSent<int>>(),
      ),
      (
        'a bad certificate',
        const bbx.BbxBadCertificateFailure(),
        isA<WriteNotSent<int>>(),
      ),
      (
        'a receive timeout that reached the classifier unclassified',
        const bbx.BbxTimeoutFailure(bbx.BbxTimeoutKind.receive),
        isA<WriteOutcomeUnknown<int>>(),
      ),
      (
        'a lost connection',
        const bbx.BbxConnectionFailure(),
        isA<WriteOutcomeUnknown<int>>(),
      ),
      (
        'an unreadable reply',
        const bbx.BbxResponseFormatFailure('invalid orderId'),
        isA<WriteOutcomeUnknown<int>>().having(
          (r) => r.reason,
          'reason',
          'invalid orderId',
        ),
      ),
    ];
    for (final (name, failure, matcher) in cases) {
      test(name, () async => expect(await write(failure), matcher));
    }
  });

  group('writeNotRun', () {
    final cases = <(ExchangeFailure, Matcher)>[
      (
        const ExchangeNotAuthenticatedFailure(),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.signedOut,
        ),
      ),
      (
        const ExchangeCredentialReadFailure(),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.credentialUnavailable,
        ),
      ),
      (
        const ExchangeOperationStaleFailure(),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.sessionChanged,
        ),
      ),
      (
        const ExchangeSessionRejectedFailure(),
        isA<WriteSessionRejected<int>>(),
      ),
      (
        const ExchangeUnsupportedNetworkFailure(),
        isA<WriteNotSent<int>>().having(
          (r) => r.reason,
          'reason',
          ExchangeNotSentReason.unreachable,
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
    Future<ExchangeRead<int>> read(bbx.BbxFailure failure) =>
        exchangeRead<int, int>('test', _fails(failure), (r) => r);

    test('a reply is Got', () async {
      expect(
        await exchangeRead<int, int>('test', _answers<int?>(3), (r) => r),
        isA<ReadGot<int>>().having((r) => r.value, 'v', 3),
      );
    });

    test('no reply is Missing, never a failure', () async {
      expect(
        await exchangeRead<int, int>('test', _answers<int?>(null), (r) => r),
        isA<ReadMissing<int>>(),
      );
    });

    test('a reply that cannot be mapped is Malformed, not a throw', () async {
      expect(
        await exchangeRead<int, int>(
          'test',
          _answers<int?>(3),
          (_) => throw StateError('x'),
        ),
        isA<ReadMalformed<int>>(),
      );
    });

    final cases = <(String, bbx.BbxFailure, Matcher)>[
      (
        'an HTTP 401',
        const bbx.BbxHttpFailure(401),
        isA<ReadSessionRejected<int>>().having(
          (r) => r.why,
          'why',
          ExchangeSessionRejection.server,
        ),
      ),
      (
        'no stored key',
        const bbx.BbxMissingCredentialFailure(),
        isA<ReadSessionRejected<int>>().having(
          (r) => r.why,
          'why',
          ExchangeSessionRejection.signedOut,
        ),
      ),
      (
        'an unreadable key',
        const bbx.BbxCredentialUnavailableFailure(),
        isA<ReadSessionRejected<int>>().having(
          (r) => r.why,
          'why',
          ExchangeSessionRejection.credentialUnavailable,
        ),
      ),
      (
        'a timeout',
        const bbx.BbxTimeoutFailure(bbx.BbxTimeoutKind.receive),
        isA<ReadUnreachable<int>>().having(
          (r) => r.isNetwork,
          'isNetwork',
          isTrue,
        ),
      ),
      (
        'a JSON-RPC error',
        const bbx.BbxRpcFailure(code: -1, message: 'account 12'),
        isA<ReadUnreachable<int>>()
            .having((r) => r.isNetwork, 'isNetwork', isFalse)
            .having((r) => r.reason, 'reason', isNot(contains('account'))),
      ),
      (
        'an HTTP 503',
        const bbx.BbxHttpFailure(503),
        isA<ReadUnreachable<int>>(),
      ),
      (
        'an unreadable reply',
        const bbx.BbxResponseFormatFailure('invalid userNumber'),
        isA<ReadMalformed<int>>(),
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
        isA<ListPage<String>>()
            .having((p) => p.items, 'items', ['1', '2'])
            .having((p) => p.next, 'next', 2),
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
          isA<ListUnreachable<int>>(),
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
        isA<ListSessionRejected<int>>(),
      );
    });

    test('an item that cannot be mapped fails the page', () async {
      expect(
        await exchangeList<int, int>(
          'test',
          _answers((items: [1], next: null)),
          (_) => throw const FormatException('x'),
        ),
        isA<ListUnreachable<int>>(),
      );
    });
  });
}
