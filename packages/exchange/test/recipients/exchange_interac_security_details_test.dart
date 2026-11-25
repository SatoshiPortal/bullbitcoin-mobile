import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../bbx_api_test_http.dart';

void main() {
  for (final isTestnet in [false, true]) {
    test('updates Interac details on testnet=$isTestnet only', () async {
      final http = FakeBbxHttp(error: DioExceptionType.connectionError);
      final exchange = testExchange(http, isTestnet: isTestnet);
      addTearDown(exchange.close);

      Future<Result<void, RecipientsFailure>> update(bool testnet) =>
          exchange.recipients.updateInteracSecurityDetails(
            recipientId: 'recipient-1',
            email: 'person@example.invalid',
            securityQuestion: 'Favourite city?',
            securityAnswer: 'Montreal',
            isTestnet: testnet,
          );

      expect(await update(!isTestnet), isA<Err<void, RecipientsFailure>>());
      expect(http.requests, isEmpty);

      switch (await update(isTestnet)) {
        case Ok():
          fail('a failed transport must not be reported as an update');
        case Err(:final failure):
          expect(failure, isA<RecipientsNetworkFailure>());
      }
      final options = http.requests.single;
      expect(
        options.uri.host,
        isTestnet ? 'testnet.example.invalid' : 'mainnet.example.invalid',
      );
      expect(options.connectTimeout, isNull);
    });
  }

  test('does not update when the session environment cannot be read', () async {
    final http = FakeBbxHttp();
    final exchange = testExchange(
      http,
      readApiKey: () async => const Err(ExchangeUnsupportedNetworkFailure()),
    );
    addTearDown(exchange.close);
    expect(
      await exchange.recipients.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.invalid',
        securityQuestion: null,
        securityAnswer: null,
        isTestnet: false,
      ),
      isA<Err<void, RecipientsFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<RecipientsUnsupportedNetworkFailure>(),
      ),
    );
    expect(http.requests, isEmpty);
  });

  test('does not confirm an update after the session has changed', () async {
    final http = FakeBbxHttp(error: DioExceptionType.connectionError);
    final exchange = exchangeWithTransportForTesting(
      readSession: () async => Ok((
        environment: ExchangeEnvironment.mainnet,
        epoch: http.requests.isEmpty ? 1 : 2,
        apiKey: anonymousTestApiKey,
      )),
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        adapter: http,
        readActiveApiKey: readKey,
      ),
    );
    addTearDown(exchange.close);

    final result = await exchange.recipients.updateInteracSecurityDetails(
      recipientId: 'recipient-1',
      email: 'person@example.invalid',
      securityQuestion: null,
      securityAnswer: null,
      isTestnet: false,
    );

    expect(
      result,
      isA<Err<void, RecipientsFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<RecipientsUnexpectedFailure>(),
      ),
    );
    expect(http.requests, hasLength(1));
  });
}
