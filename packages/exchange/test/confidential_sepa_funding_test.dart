import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

void main() {
  const eligible = ['KYC_IDENTITY_VERIFIED', 'JURI_EU'];
  late FakeBbxHttp account;
  late FakeBbxHttp ibans;
  late int epoch;
  late Exchange exchange;

  FakeBbxHttp summary(List<String> groups) => FakeBbxHttp(
    body: {
      'result': {
        'userNumber': 42,
        'userId': 'test-user',
        'groups': groups,
        'profile': {'firstName': 'Test', 'lastName': 'User'},
        'email': 'test@example.invalid',
        'balances': [],
        'currency': 'EUR',
        'dca': {'isActive': false},
        'autoBuy': {'isActive': false, 'addresses': <String, String>{}},
      },
    },
  );

  setUp(() {
    epoch = 0;
    account = summary(eligible);
    ibans = FakeBbxHttp(
      body: {
        'result': {'elements': [], 'totalElements': 0},
      },
    );
    exchange = exchangeWithTransportForTesting(
      readSession: () async => Ok((
        environment: ExchangeEnvironment.testnet,
        epoch: epoch,
        apiKey: 'synthetic-key',
      )),
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        readActiveApiKey: readKey,
        adapter: account,
      ),
      openUntimedClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        readActiveApiKey: readKey,
        adapter: ibans,
      ),
    );
    addTearDown(exchange.close);
  });

  test('offers funding before there is a virtual IBAN', () async {
    final result = await exchange.isConfidentialSepaFundingAvailable();
    expect(result, isA<Ok<bool, ExchangeFailure>>());
    expect((result as Ok<bool, ExchangeFailure>).value, isTrue);
    expect(ibans.requests.single.uri.host, startsWith('testnet'));
    expect(ibans.requests.single.path, '/ak/api-recipients');
  });

  test('does not look up IBANs for an ineligible account', () async {
    account = summary([...eligible, 'KYC_IS_CORPORATE']);
    final result = await exchange.isConfidentialSepaFundingAvailable();
    expect(result, isA<Ok<bool, ExchangeFailure>>());
    expect((result as Ok<bool, ExchangeFailure>).value, isFalse);
    expect(ibans.requests, isEmpty);
  });

  test('a failed IBAN lookup is not eligibility', () async {
    ibans = FakeBbxHttp(error: DioExceptionType.connectionTimeout);
    final result = await exchange.isConfidentialSepaFundingAvailable();
    expect(
      result,
      isA<Err<bool, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeNetworkFailure>(),
      ),
    );
  });

  test('does not publish a result from an earlier credential epoch', () async {
    var reads = 0;
    final changingExchange = exchangeWithTransportForTesting(
      readSession: () async => Ok((
        environment: ExchangeEnvironment.mainnet,
        epoch: reads++ < 2 ? 0 : 1,
        apiKey: 'synthetic-key',
      )),
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        readActiveApiKey: readKey,
        adapter: account,
      ),
      openUntimedClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        readActiveApiKey: readKey,
        adapter: ibans,
      ),
    );
    addTearDown(changingExchange.close);
    final result = await changingExchange.isConfidentialSepaFundingAvailable();
    expect(
      result,
      isA<Err<bool, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeOperationStaleFailure>(),
      ),
    );
    expect(ibans.requests, isEmpty);
  });
}
