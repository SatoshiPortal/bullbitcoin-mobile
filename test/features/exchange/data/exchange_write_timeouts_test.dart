import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_locator.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/limit_orders_locator.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/recipients_locator.dart';
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

        LimitOrdersLocator.setup(locator);
        RecipientsLocator.registerRepositories(locator);
        FundExchangeLocator.registerRepositories(locator);
        final isTestnet = environment == Environment.testnet;
        final results = await Future.wait([
          locator<LimitOrderRepository>().create(
            LimitOrderDraft(
              limitPrice: 90000,
              fiatAmount: 100,
              currencyCode: 'CAD',
              address: 'bc1qaddress',
            ),
          ),
          locator<RecipientsRepository>().saveRecipient(
            InteracEmailCadDetails.create(
              email: 'recipient@example.invalid',
              name: 'Recipient',
            ),
            isTestnet: isTestnet,
          ),
          locator<VirtualIbanRepository>().create(isTestnet: isTestnet),
          locator<SepaVirtualPayeeRepository>().activate(
            recipientId: 'fixture-recipient',
            isTestnet: isTestnet,
          ),
          locator<FundingRepository>().registerResponsibilityConsent(),
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
        for (final adapter in adapters.values) {
          expect(adapter.requests, isEmpty);
        }
      },
    );
  }
}
