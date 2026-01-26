import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
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
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:dio/dio.dart';

class RecipientsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {
    sl.registerLazySingleton<BullbitcoinApiKeyProvider>(
      () => BullbitcoinApiKeyProvider(
        secureStorage: sl<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    sl.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: false,
        apiKeyProvider: sl(),
      ),
      instanceName: 'authenticatedBullBitcoinApiClient',
    );

    sl.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: true,
        apiKeyProvider: sl(),
      ),
      instanceName: 'authenticatedBullBitcoinApiTestClient',
    );
  }

  @override
  Future<void> registerDrivenAdapters() async {
    // Only register the DelegatingRecipientsGateway here, since it
    // encapsulates both the mainnet and testnet gateways, which shouldn't be
    // used directly/independently for now.
    sl.registerLazySingleton<RecipientsGatewayPort>(
      () => DelegatingRecipientsGateway(
        bullbitcoinApiClient: BullbitcoinApiRecipientsGateway(
          authenticatedApiClient: sl<Dio>(
            instanceName: 'authenticatedBullBitcoinApiClient',
          ),
        ),
        bullBitcoinTestnetApiClient: BullbitcoinApiRecipientsGateway(
          authenticatedApiClient: sl<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
      ),
    );
  }

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<AddRecipientUsecase>(
      () => AddRecipientUsecase(
        recipientsGateway: sl(),
        settingsRepository: sl(),
      ),
    );
    sl.registerFactory<GetRecipientsUsecase>(
      () => GetRecipientsUsecase(
        recipientsGateway: sl(),
        settingsRepository: sl(),
      ),
    );
    sl.registerFactory<CheckSinpeUsecase>(
      () =>
          CheckSinpeUsecase(recipientsGateway: sl(), settingsRepository: sl()),
    );
    sl.registerFactory<ListCadBillersUsecase>(
      () => ListCadBillersUsecase(
        recipientsGateway: sl(),
        settingsRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactoryParam<
      RecipientsBloc,
      RecipientFilterCriteria?,
      Future<void>? Function(
        RecipientViewModel recipient, {
        required bool isNew,
      })?
    >(
      (allowedRecipientFilters, onRecipientSelected) => RecipientsBloc(
        allowedRecipientFilters: allowedRecipientFilters,
        onRecipientSelectedHook: onRecipientSelected,
        addRecipientUsecase: sl(),
        getRecipientsUsecase: sl(),
        checkSinpeUsecase: sl(),
        listCadBillersUsecase: sl(),
      ),
    );
  }
}
