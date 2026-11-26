import 'package:bbx_api/bbx_api.dart'
    show BbxCredentialUnavailableFailure, BbxFailure;
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/bbx_api_account_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

const _summary = {
  'userNumber': 7,
  'groups': <String>[],
  'profile': {'firstName': 'A', 'lastName': 'B'},
  'email': 'a@example.com',
  'balances': <Object>[],
  'dca': {'isActive': false},
  'autoBuy': {'isActive': false, 'addresses': <String, Object>{}},
};

Future<Result<UserSummary, ExchangeFailure>> _account(
  FakeBbxHttp http, {
  Future<Result<String?, BbxFailure>> Function()? readApiKey,
}) => BbxApiAccountRepository(http.client(readApiKey: readApiKey)).getAccount();

ExchangeFailure _failureOf(Result<UserSummary, ExchangeFailure> result) =>
    switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };

void main() {
  test('maps the account', () async {
    final result = await _account(FakeBbxHttp(body: {'result': _summary}));
    final summary = (result as Ok<UserSummary, ExchangeFailure>).value;
    expect(summary.userNumber, 7);
    expect(summary.email, 'a@example.com');
  });

  test('missing JSON-RPC result never reports a rejected session', () async {
    expect(
      _failureOf(await _account(FakeBbxHttp(body: {'result': null}))),
      isA<ExchangeAccountUnavailableFailure>(),
    );
  });

  test('401 is a definitive refusal; 403 and 503 retain the session', () async {
    for (final status in [401, 403, 503]) {
      final failure = _failureOf(
        await _account(FakeBbxHttp(status: status, body: const {})),
      );
      expect(
        failure,
        status == 401
            ? isA<ExchangeSessionRejectedFailure>()
            : isA<ExchangeAccountUnavailableFailure>(),
      );
      expect(failure.logMessage, isNull);
    }
  });

  test('a missing local key is not a server rejection', () async {
    final http = FakeBbxHttp(body: {'result': _summary});
    expect(
      _failureOf(await _account(http, readApiKey: () async => const Ok(null))),
      isA<ExchangeNotAuthenticatedFailure>(),
    );
    expect(http.requests, isEmpty);
  });

  test('an unreadable local key does not look like logout', () async {
    expect(
      _failureOf(
        await _account(
          FakeBbxHttp(),
          readApiKey: () async => const Err(BbxCredentialUnavailableFailure()),
        ),
      ),
      isA<ExchangeAccountUnavailableFailure>(),
    );
  });

  test('a timeout is a network failure', () async {
    expect(
      _failureOf(
        await _account(FakeBbxHttp(error: DioExceptionType.connectionTimeout)),
      ),
      isA<ExchangeNetworkFailure>(),
    );
  });

  test('a malformed account is unavailable', () async {
    expect(
      _failureOf(
        await _account(
          FakeBbxHttp(
            body: {
              'result': {..._summary, 'groups': null},
            },
          ),
        ),
      ),
      isA<ExchangeAccountUnavailableFailure>(),
    );
  });
}
