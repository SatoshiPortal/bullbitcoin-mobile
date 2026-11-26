import 'dart:typed_data';

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
        adapter: _ByPath(() => account, () => ibans),
      ),
    );
    addTearDown(exchange.close);
  });

  test('offers funding before there is a virtual IBAN', () async {
    final result = await exchange.getConfidentialSepaAvailability();
    expect(result, isA<Ok<ConfidentialSepaAvailability, ExchangeFailure>>());
    expect(
      (result as Ok<ConfidentialSepaAvailability, ExchangeFailure>).value,
      ConfidentialSepaAvailability.needsVirtualIban,
    );
    expect(ibans.requests.single.uri.host, startsWith('testnet'));
    expect(ibans.requests.single.path, '/ak/api-recipients');
  });

  for (final (name, groups) in [
    ('corporate', [...eligible, 'KYC_IS_CORPORATE']),
    ('outside the EU', ['KYC_IDENTITY_VERIFIED']),
    ('without full KYC', ['KYC_CANADA_LIGHT_VERIFICATION', 'JURI_EU']),
  ]) {
    test('does not look up IBANs for an account $name', () async {
      account = summary(groups);
      final result = await exchange.getConfidentialSepaAvailability();
      expect(
        (result as Ok<ConfidentialSepaAvailability, ExchangeFailure>).value,
        ConfidentialSepaAvailability.unavailable,
      );
      expect(ibans.requests, isEmpty);
    });
  }

  for (final active in [false, true]) {
    test('distinguishes an active IBAN from a pending one ($active)', () async {
      ibans = FakeBbxHttp(
        body: {
          'result': {
            'elements': [
              {
                'recipientId': 'viban-1',
                if (active) ...{
                  'iban': 'FR7616958000016918327146718',
                  'bicCode': 'FIRPFRP2',
                  'bankAddress': '1 Rue de la Paix, Paris',
                  'ibanCountry': 'FR',
                },
              },
            ],
            'totalElements': 1,
          },
        },
      );
      final result = await exchange.getConfidentialSepaAvailability();
      expect(
        (result as Ok<ConfidentialSepaAvailability, ExchangeFailure>).value,
        active
            ? ConfidentialSepaAvailability.ready
            : ConfidentialSepaAvailability.needsVirtualIban,
      );
    });
  }

  test('an unreadable account is not eligibility', () async {
    account = FakeBbxHttp(status: 401);
    final result = await exchange.getConfidentialSepaAvailability();
    expect(
      (result as Err<ConfidentialSepaAvailability, ExchangeFailure>).failure,
      isA<ExchangeAccountUnavailableFailure>(),
    );
    expect(ibans.requests, isEmpty);
  });

  test('a failed IBAN lookup is not eligibility', () async {
    ibans = FakeBbxHttp(error: DioExceptionType.connectionTimeout);
    final result = await exchange.getConfidentialSepaAvailability();
    expect(
      result,
      isA<Err<ConfidentialSepaAvailability, ExchangeFailure>>().having(
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
        adapter: _ByPath(() => account, () => ibans),
      ),
    );
    addTearDown(changingExchange.close);
    final result = await changingExchange.getConfidentialSepaAvailability();
    expect(
      result,
      isA<Err<ConfidentialSepaAvailability, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeOperationStaleFailure>(),
      ),
    );
    expect(ibans.requests, isEmpty);
  });
}

/// Sends the recipients calls to [recipients] and every other call to
/// [others]: one client carries both, as in the app.
final class _ByPath implements HttpClientAdapter {
  final FakeBbxHttp Function() others;
  final FakeBbxHttp Function() recipients;

  _ByPath(this.others, this.recipients);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => (options.path.endsWith('/api-recipients') ? recipients() : others())
      .fetch(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) {}
}
