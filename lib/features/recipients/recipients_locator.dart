import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/data/datasources/bullbitcoin_api_sepa_virtual_payee_datasource.dart';
import 'package:bb_mobile/features/recipients/data/datasources/bullbitcoin_api_virtual_iban_datasource.dart';
import 'package:bb_mobile/features/recipients/data/interac_security_details_repository_impl.dart';
import 'package:bb_mobile/features/recipients/data/sepa_virtual_payee_repository_impl.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/update_interac_security_details_usecase.dart';
import 'package:bb_mobile/features/recipients/data/bullbitcoin_api_recipients_repository.dart';
import 'package:bb_mobile/features/recipients/data/recipients_repository_impl.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/presentation/sepa_virtual_payee_activation_cubit.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class RecipientsLocator {
  static void setup(GetIt locator) {
    registerRepositories(locator);
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerRepositories(GetIt locator) {
    // Only register the RecipientsRepositoryImpl here, since it
    // encapsulates both the mainnet and testnet repositories, which shouldn't be
    // used directly/independently for now.
    locator.registerLazySingleton<RecipientsRepository>(
      () => RecipientsRepositoryImpl(
        bullbitcoinApiClient: BullbitcoinApiRecipientsRepository(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiClient',
          ),
        ),
        bullBitcoinTestnetApiClient: BullbitcoinApiRecipientsRepository(
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

  static void registerUsecases(GetIt locator) {
    // Register application services and use cases here
    // One boundary for the throwing core settings read, shared by the four
    // recipient use-cases.
    locator.registerFactory<GetRecipientsEnvironmentUsecase>(
      () => GetRecipientsEnvironmentUsecase(locator<SettingsRepository>()),
    );
    locator.registerFactory<AddRecipientUsecase>(
      () => AddRecipientUsecase(
        recipientsRepository: locator<RecipientsRepository>(),
        sepaVirtualPayeeRepository: locator<SepaVirtualPayeeRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<GetRecipientsUsecase>(
      () => GetRecipientsUsecase(
        recipientsRepository: locator<RecipientsRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<CheckSinpeUsecase>(
      () => CheckSinpeUsecase(
        recipientsRepository: locator<RecipientsRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<GetPreferredJurisdictionUsecase>(
      () => GetPreferredJurisdictionUsecase(
        locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
    locator.registerFactory<GetAccountOwnerNameUsecase>(
      () =>
          GetAccountOwnerNameUsecase(locator<GetExchangeUserSummaryUsecase>()),
    );
    locator.registerFactory<GetConfidentialSepaAvailabilityUsecase>(
      () => GetConfidentialSepaAvailabilityUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        virtualIbanRepository: locator<VirtualIbanRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<ListCadBillersUsecase>(
      () => ListCadBillersUsecase(
        recipientsRepository: locator<RecipientsRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
      ),
    );
    locator.registerFactory<WatchVirtualIbanUsecase>(
      () => WatchVirtualIbanUsecase(
        virtualIbanRepository: locator<VirtualIbanRepository>(),
        getRecipientsEnvironmentUsecase:
            locator<GetRecipientsEnvironmentUsecase>(),
        exchangeNotificationRepository:
            locator<ExchangeNotificationRepository>(),
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
        locator<RecipientsRepository>(),
        locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<RecipientsFacade>(
      () => RecipientsFacade(
        locator<UpdateInteracSecurityDetailsUsecase>(),
        locator<GetConfidentialSepaAvailabilityUsecase>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<SepaVirtualPayeeActivationCubit, String, void>(
      (recipientId, _) => SepaVirtualPayeeActivationCubit(
        watchSepaVirtualPayeeActivationUsecase:
            locator<WatchSepaVirtualPayeeActivationUsecase>(),
        recipientId: recipientId,
      ),
    );
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
        getConfidentialSepaAvailabilityUsecase:
            locator<GetConfidentialSepaAvailabilityUsecase>(),
        getAccountOwnerNameUsecase: locator<GetAccountOwnerNameUsecase>(),
        addRecipientUsecase: locator<AddRecipientUsecase>(),
        getRecipientsUsecase: locator<GetRecipientsUsecase>(),
        checkSinpeUsecase: locator<CheckSinpeUsecase>(),
        listCadBillersUsecase: locator<ListCadBillersUsecase>(),
      ),
    );
  }
}
