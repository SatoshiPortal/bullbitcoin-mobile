import 'package:preferences/preferences.dart' show Environment;
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bbx_api/bbx_api.dart' show BbxTimeouts, RecipientsApi;
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

void main() {
  for (final environment in [Environment.mainnet, Environment.testnet]) {
    test('exchange writes use the ${environment.name} client with the 30 s '
        'timeouts (INT-11, RCP-16)', () async {
      final adapters = {
        for (final network in [Environment.mainnet, Environment.testnet])
          network: FakeBbxHttp(error: DioExceptionType.connectionError),
      };

      final exchange = exchangeWithTransportForTesting(
        readSession: () async => Ok((
          environment: environment == Environment.testnet
              ? ExchangeEnvironment.testnet
              : ExchangeEnvironment.mainnet,
          epoch: 0,
          apiKey: 'synthetic-key',
        )),
        openClient: (endpoint, readKey) {
          final network = endpoint.host.startsWith('testnet')
              ? Environment.testnet
              : Environment.mainnet;
          return bbxForTesting(
            endpoint: endpoint.toString(),
            adapter: adapters[network]!,
            readActiveApiKey: readKey,
            timeouts: BbxTimeouts.standard,
          );
        },
      );
      final isTestnet = environment == Environment.testnet;
      final results = await Future.wait([
        exchange.limitOrders.create(
          LimitOrderDraft(
            limitPrice: 90000,
            fiatAmount: 100,
            currency: FiatCurrency.cad,
            address: 'bc1qaddress',
          ),
        ),
        exchange.recipients.saveRecipient(
          InteracEmailCadDetails.create(
            email: 'recipient@example.invalid',
            name: 'Recipient',
          ),
          isTestnet: isTestnet,
        ),
        exchange.virtualIbans.create(
          isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
        ),
        exchange.recipients.activate(
          recipientId: 'fixture-recipient',
          isTestnet: isTestnet,
        ),
      ]);
      expect(results, everyElement(isA<Err<Object?, Failure>>()));
      expect(
        await exchange.funding.consent(
          ExchangeSession(
            environment: environment == Environment.testnet
                ? ExchangeEnvironment.testnet
                : ExchangeEnvironment.mainnet,
            epoch: 0,
            sessionId: 'session',
          ),
        ),
        isA<WriteOutcomeUnknown<void>>(),
      );

      final selected = adapters.remove(environment);
      expect(
        selected?.requests.map((request) => (request.data as Map)['method']),
        unorderedEquals([
          'addLimitOrder',
          'createRecipientFiat',
          'createMyRecipient',
          'activateSepaVirtualPayee',
          'registerResponsibilityConsent',
        ]),
      );
      expect(
        selected?.requests,
        everyElement(
          isA<RequestOptions>()
              .having(
                (options) => options.connectTimeout,
                'connect',
                const Duration(seconds: 30),
              )
              .having(
                (options) => options.sendTimeout,
                'send',
                const Duration(seconds: 30),
              )
              .having(
                (options) => options.receiveTimeout,
                'receive',
                isNotNull,
              ),
        ),
      );
      for (final request in selected!.requests) {
        final method = (request.data as Map)['method'];
        expect(request.receiveTimeout, switch (method) {
          // The server answers these only after polling Fiat Republic.
          'createMyRecipient' ||
          'activateSepaVirtualPayee' => RecipientsApi.virtualIbanReceiveTimeout,
          _ => const Duration(seconds: 30),
        }, reason: '$method');
      }
      for (final adapter in adapters.values) {
        expect(adapter.requests, isEmpty);
      }
    });
  }
}
