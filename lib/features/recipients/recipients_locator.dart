import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
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
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';

class RecipientsLocator {
  static void setup() {
    registerFrameworks();
    registerDrivenInterfaceAdapters();
    registerApplicationServicesAndUseCases();
    registerDrivingInterfaceAdapters();
  }

  static void registerFrameworks() {
    locator.registerLazySingleton<BullbitcoinApiKeyProvider>(
      () => BullbitcoinApiKeyProvider(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
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
      Future<void>? Function(RecipientViewModel recipient)?
    >(
      (allowedRecipientFilters, onRecipientSelected) => RecipientsBloc(
        allowedRecipientFilters: allowedRecipientFilters,
        onRecipientSelectedHook: onRecipientSelected,
        addRecipientUsecase: locator<AddRecipientUsecase>(),
        getRecipientsUsecase: locator<GetRecipientsUsecase>(),
        checkSinpeUsecase: locator<CheckSinpeUsecase>(),
        listCadBillersUsecase: locator<ListCadBillersUsecase>(),
      ),
    );
  }
}
