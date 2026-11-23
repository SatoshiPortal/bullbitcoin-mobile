import 'package:preferences/preferences.dart' show Environment;
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bbx_api/bbx_api.dart' show BbxTimeouts;
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
        exchange.funding.registerResponsibilityConsent(),
      ]);
      expect(results, everyElement(isA<Err<Object?, Failure>>()));

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
                const Duration(seconds: 30),
              ),
        ),
      );
      for (final adapter in adapters.values) {
        expect(adapter.requests, isEmpty);
      }
    });
  }
}
