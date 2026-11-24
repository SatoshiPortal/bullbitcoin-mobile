import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bbx_api/bbx_api.dart' show Bbx, BbxTimeouts;
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

class _SettingsRepository extends Mock implements Preferences {}

void main() {
  for (final environment in [Environment.mainnet, Environment.testnet]) {
    test(
      'exchange writes use the untimed ${environment.name} client',
      () async {
        final locator = GetIt.asNewInstance();
        addTearDown(locator.reset);
        final settings = _SettingsRepository();
        when(settings.fetch).thenAnswer(
          (_) async => Ok(
            SettingsEntity(
              environment: environment,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
            ),
          ),
        );
        locator.registerSingleton<Preferences>(settings);
        locator.registerSingleton(settings);

        final adapters = <(Environment, bool), FakeBbxHttp>{};
        for (final network in [Environment.mainnet, Environment.testnet]) {
          for (final timed in [true, false]) {
            final http = FakeBbxHttp(error: DioExceptionType.connectionError);
            final suffix = timed ? '' : 'WithoutTimeout';
            locator.registerSingleton<Bbx>(
              bbxForTesting(
                endpoint: 'https://example.invalid',
                adapter: http,
                readActiveApiKey: bbxCredentialRead(null),
                timeouts: timed ? BbxTimeouts.standard : const BbxTimeouts(),
              ),
              instanceName: '${network.name}BbxApiClient$suffix',
            );
            adapters[(network, timed)] = http;
          }
        }

        final exchange = exchangeWithTransportForTesting(
          readSession: () async => Ok((
            environment: environment == Environment.testnet
                ? ExchangeEnvironment.testnet
                : ExchangeEnvironment.mainnet,
            epoch: 0,
            apiKey: anonymousTestApiKey,
          )),
          openClient: (_, _) => fail('unexpected timed operation'),
          openUntimedClient: (endpoint, readKey) {
            final network = endpoint.host.startsWith('testnet')
                ? Environment.testnet
                : Environment.mainnet;
            final http = adapters[(network, false)];
            if (http == null) fail('missing untimed adapter');
            return bbxForTesting(
              endpoint: endpoint.toString(),
              adapter: http,
              readActiveApiKey: readKey,
            );
          },
        );
        final isTestnet = environment == Environment.testnet;
        final results = await Future.wait([
          exchange.limitOrders.create(
            LimitOrderDraft(
              limitPrice: 90000,
              fiatAmount: 100,
              currencyCode: 'CAD',
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
            isTestnet
                ? ExchangeEnvironment.testnet
                : ExchangeEnvironment.mainnet,
          ),
          exchange.recipients.activate(
            recipientId: 'fixture-recipient',
            isTestnet: isTestnet,
          ),
          exchange.funding.registerResponsibilityConsent(),
        ]);
        expect(results, everyElement(isA<Err<Object?, Failure>>()));

        final selected = adapters.remove((environment, false));
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
                .having((options) => options.connectTimeout, 'connect', isNull)
                .having((options) => options.sendTimeout, 'send', isNull)
                .having((options) => options.receiveTimeout, 'receive', isNull),
          ),
        );
        for (final adapter in adapters.values) {
          expect(adapter.requests, isEmpty);
        }
      },
    );
  }
}
