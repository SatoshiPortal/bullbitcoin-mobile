import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/frameworks/http/authenticated_bullbitcoin_dio_factory.dart';
import 'package:bb_mobile/features/recipients/frameworks/http/bullbitcoin_api_key_provider.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/delegating_recipients_gateway.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecipientsLocator {
  static void setup() {
    // Register recipients feature dependencies here
  }

  static void registerFrameworks() {
    // TODO: These instances should be moved to the core/shared locator so they can
    //  be used by other features that need to call the Bull Bitcoin API, without
    //  needing to have one big datasource with all API calls in it.
    locator.registerLazySingleton<BullbitcoinApiKeyProvider>(
      () => BullbitcoinApiKeyProvider(
        secureStorage: locator<FlutterSecureStorage>(),
      ),
    );

    locator.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: false,
        apiKeyProvider: locator<BullbitcoinApiKeyProvider>(),
      ),
      instanceName: 'authenticatedBullBitcoinApiClient',
    );

    locator.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: true,
        apiKeyProvider: locator<BullbitcoinApiKeyProvider>(),
      ),
      instanceName: 'authenticatedBullBitcoinApiTestClient',
    );
  }

  static void registerDrivenInterfaceAdapters() {
    // Only register the DelegatingRecipientsGateway here, since it
    // encapsulates both the mainnet and testnet gateways, which shouldn't be
    // used directly/independently for now.
    locator.registerLazySingleton<RecipientsGatewayPort>(
      () => DelegatingRecipientsGateway(
        bullbitcoinApiClient: BullbitcoinApiRecipientsGateway(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiClient',
          ),
        ),
        bullBitcoinTestnetApiClient: BullbitcoinApiRecipientsGateway(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
      ),
    );
  }
}
