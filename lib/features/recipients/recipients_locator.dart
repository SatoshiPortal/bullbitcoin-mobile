import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/data/bullbitcoin_api_sepa_virtual_payee_datasource.dart';
import 'package:bb_mobile/features/recipients/data/bullbitcoin_api_virtual_iban_datasource.dart';
import 'package:bb_mobile/features/recipients/data/interac_security_details_repository_impl.dart';
import 'package:bb_mobile/features/recipients/data/sepa_virtual_payee_repository_impl.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/update_interac_security_details_usecase.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/delegating_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class RecipientsLocator {
  static void setup(GetIt locator) {
    registerDrivenInterfaceAdapters(locator);
    registerApplicationServicesAndUseCases(locator);
    registerDrivingInterfaceAdapters(locator);
  }

  static void registerDrivenInterfaceAdapters(GetIt locator) {
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
    locator.registerLazySingleton<VirtualIbanRepository>(
      () => VirtualIbanRepositoryImpl(
        mainnetDatasource: BullbitcoinApiVirtualIbanDatasource(
          http: locator<Dio>(instanceName: 'authenticatedBullBitcoinApiClient'),
        ),
        testnetDatasource: BullbitcoinApiVirtualIbanDatasource(
          http: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
      ),
    );
    locator.registerLazySingleton<SepaVirtualPayeeRepository>(
      () => SepaVirtualPayeeRepositoryImpl(
        mainnetDatasource: BullbitcoinApiSepaVirtualPayeeDatasource(
          http: locator<Dio>(instanceName: 'authenticatedBullBitcoinApiClient'),
        ),
        testnetDatasource: BullbitcoinApiSepaVirtualPayeeDatasource(
          http: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
      ),
    );
  }

  static void registerApplicationServicesAndUseCases(GetIt locator) {
    // Register application services and use cases here
    // One boundary for the throwing core settings read, shared by the four
    // recipient use-cases.
    locator.registerFactory<GetRecipientsEnvironmentUsecase>(
      () => GetRecipientsEnvironmentUsecase(locator<SettingsRepository>()),
    );
    locator.registerFactory<AddRecipientUsecase>(
      () => AddRecipientUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<GetRecipientsUsecase>(
      () => GetRecipientsUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<CheckSinpeUsecase>(
      () => CheckSinpeUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<GetPreferredJurisdictionUsecase>(
      () => GetPreferredJurisdictionUsecase(
        locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
    locator.registerFactory<ListCadBillersUsecase>(
      () => ListCadBillersUsecase(
        recipientsGateway: locator<RecipientsGatewayPort>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<WatchVirtualIbanUsecase>(
      () => WatchVirtualIbanUsecase(
        virtualIbanRepository: locator<VirtualIbanRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<WatchSepaVirtualPayeeActivationUsecase>(
      () => WatchSepaVirtualPayeeActivationUsecase(
        sepaVirtualPayeeRepository: locator<SepaVirtualPayeeRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<UpdateInteracSecurityDetailsUsecase>(
      () => UpdateInteracSecurityDetailsUsecase(
        locator<InteracSecurityDetailsRepository>(),
      ),
    );
    locator.registerLazySingleton<InteracSecurityDetailsRepository>(
      () => InteracSecurityDetailsRepositoryImpl(
        locator<RecipientsGatewayPort>(),
        locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<RecipientsFacade>(
      () => RecipientsFacade(locator<UpdateInteracSecurityDetailsUsecase>()),
    );
  }

  static void registerDrivingInterfaceAdapters(GetIt locator) {
    // Register presenters, controllers, etc. here
    locator.registerFactoryParam<
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
        getPreferredJurisdictionUsecase:
            locator<GetPreferredJurisdictionUsecase>(),
        addRecipientUsecase: locator<AddRecipientUsecase>(),
        getRecipientsUsecase: locator<GetRecipientsUsecase>(),
        checkSinpeUsecase: locator<CheckSinpeUsecase>(),
        listCadBillersUsecase: locator<ListCadBillersUsecase>(),
      ),
    );
  }
}
