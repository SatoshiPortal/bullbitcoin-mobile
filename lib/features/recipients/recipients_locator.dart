import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/frameworks/http/authenticated_bullbitcoin_dio_factory.dart';
import 'package:bb_mobile/features/recipients/frameworks/http/bullbitcoin_api_key_provider.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/delegating_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_filters_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecipientsLocator {
  static void setup() {
    // Register recipients feature dependencies here
    registerFrameworks();
    registerDrivenInterfaceAdapters();
    registerApplicationServicesAndUseCases();
    registerDrivingInterfaceAdapters();
  }

  static void registerFrameworks() {
    // TODO: These instances should be moved to the core/shared locator so they can
    //  be used by other features that need to call the Bull Bitcoin API, without
    //  needing to have one big datasource with all API calls in it. Every feature
    //  could then just reuse the clients and implement only the api calls they need
    //  in their own gateways.
    // The secure_storage and secure_storage_datasource were so much overkill,
    // we should just share one instance with the settings like this.
    locator.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    );
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

  static void registerApplicationServicesAndUseCases() {
    // Register application services and use cases here
    locator.registerFactory<AddRecipientUsecase>(
      () => AddRecipientUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetRecipientsUsecase>(
      () => GetRecipientsUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<CheckSinpeUsecase>(
      () => CheckSinpeUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<ListCadBillersUsecase>(
      () => ListCadBillersUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }

  static void registerDrivingInterfaceAdapters() {
    // Register presenters, controllers, etc. here
    locator.registerFactoryParam<
      RecipientsBloc,
      AllowedRecipientFiltersViewModel?,
      void
    >(
      (allowedRecipientFilters, _) => RecipientsBloc(
        allowedRecipientFilters: allowedRecipientFilters,
        addRecipientUsecase: locator<AddRecipientUsecase>(),
        getRecipientsUsecase: locator<GetRecipientsUsecase>(),
        checkSinpeUsecase: locator<CheckSinpeUsecase>(),
        listCadBillersUsecase: locator<ListCadBillersUsecase>(),
      ),
    );
  }
}
