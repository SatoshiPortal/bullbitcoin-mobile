import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/data/sepa_virtual_payee_repository_impl.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/check_confidential_sepa_eligibility_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/delegating_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/presentation/fr_payee_activation_cubit.dart';
import 'package:bb_mobile/features/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
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
    locator.registerLazySingleton<DelegatingRecipientsGateway>(
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
    locator.registerLazySingleton<RecipientsGatewayPort>(
      () => locator<DelegatingRecipientsGateway>(),
    );
    locator.registerLazySingleton<SepaVirtualPayeeRepository>(
      () => SepaVirtualPayeeRepositoryImpl(
        locator<Dio>(instanceName: 'authenticatedBullBitcoinApiClient'),
        locator<Dio>(instanceName: 'authenticatedBullBitcoinApiTestClient'),
      ),
    );
    locator.registerLazySingleton<VirtualIbanRepository>(
      () => VirtualIbanRepositoryImpl(
        locator<Dio>(instanceName: 'authenticatedBullBitcoinApiClient'),
        locator<Dio>(instanceName: 'authenticatedBullBitcoinApiTestClient'),
      ),
    );
  }

  static void registerApplicationServicesAndUseCases(GetIt locator) {
    // Register application services and use cases here
    locator.registerFactory<AddRecipientUsecase>(
      () => AddRecipientUsecase(
        locator<SepaVirtualPayeeRepository>(),
        recipientsGateway: locator<RecipientsGatewayPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchSepaVirtualPayeeActivationUsecase>(
      () => WatchSepaVirtualPayeeActivationUsecase(
        locator<SepaVirtualPayeeRepository>(),
        locator<domain.SettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchVirtualIbanActivationUsecase>(
      () => WatchVirtualIbanActivationUsecase(
        locator<VirtualIbanRepository>(),
        locator<domain.SettingsRepository>(),
      ),
    );
    locator.registerFactory<CheckConfidentialSepaEligibilityUsecase>(
      CheckConfidentialSepaEligibilityUsecase.new,
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

  static void registerDrivingInterfaceAdapters(GetIt locator) {
    // Register presenters, controllers, etc. here
    locator
        .registerFactoryParam<FrPayeeActivationCubit, RecipientViewModel, void>(
          (recipient, _) => FrPayeeActivationCubit(
            locator<WatchSepaVirtualPayeeActivationUsecase>(),
            recipient: recipient,
          ),
        );
    locator.registerFactory<VirtualIbanOnboardingCubit>(
      () => VirtualIbanOnboardingCubit(
        locator<WatchVirtualIbanActivationUsecase>(),
      ),
    );
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
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        checkConfidentialSepaEligibilityUsecase:
            locator<CheckConfidentialSepaEligibilityUsecase>(),
        addRecipientUsecase: locator<AddRecipientUsecase>(),
        getRecipientsUsecase: locator<GetRecipientsUsecase>(),
        checkSinpeUsecase: locator<CheckSinpeUsecase>(),
        listCadBillersUsecase: locator<ListCadBillersUsecase>(),
      ),
    );
  }
}
