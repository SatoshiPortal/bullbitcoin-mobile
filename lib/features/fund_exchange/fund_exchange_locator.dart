import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/fund_exchange/domain/exchange_environment_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/external_link_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/data/settings_exchange_environment_adapter.dart';
import 'package:bb_mobile/features/fund_exchange/data/url_launcher_external_link_adapter.dart';
import 'package:bb_mobile/features/fund_exchange/data/bullbitcoin_api_funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/data/funding_repository_impl.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class FundExchangeLocator {
  static void setup(GetIt locator) {
    registerRepositories(locator);
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<ExchangeEnvironmentPort>(
      () => SettingsExchangeEnvironmentAdapter(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
    );

    locator.registerLazySingleton<ExternalLinkPort>(
      () => const UrlLauncherExternalLinkAdapter(),
    );

    locator.registerLazySingleton<FundingRepository>(
      () => FundingRepositoryImpl(
        bullbitcoinFundingRepository: BullBitcoinApiFundingRepository(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiClient',
          ),
        ),
        bullBitcoinTestnetFundingRepository: BullBitcoinApiFundingRepository(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
        exchangeEnvironment: locator<ExchangeEnvironmentPort>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<ListFundingInstitutionsUsecase>(
      () => ListFundingInstitutionsUsecase(
        fundingRepository: locator<FundingRepository>(),
      ),
    );

    locator.registerFactory<GetFundingDetailsUsecase>(
      () => GetFundingDetailsUsecase(
        fundingRepository: locator<FundingRepository>(),
      ),
    );

    locator.registerFactory<RegisterResponsibilityConsentUsecase>(
      () => RegisterResponsibilityConsentUsecase(
        fundingRepository: locator<FundingRepository>(),
      ),
    );

    locator.registerFactory<GetFundExchangeUserSummaryUsecase>(
      () => GetFundExchangeUserSummaryUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );

    locator.registerFactory<GetConfidentialSepaFundingAvailabilityUsecase>(
      () => GetConfidentialSepaFundingAvailabilityUsecase(
        locator<RecipientsFacade>(),
      ),
    );
    locator.registerFactory<OpenFundingPaymentLinkUsecase>(
      () => OpenFundingPaymentLinkUsecase(
        externalLink: locator<ExternalLinkPort>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<FundExchangeBloc>(
      () => FundExchangeBloc(
        getFundExchangeUserSummaryUsecase:
            locator<GetFundExchangeUserSummaryUsecase>(),
        listFundingInstitutionsUsecase:
            locator<ListFundingInstitutionsUsecase>(),
        getFundingDetailsUsecase: locator<GetFundingDetailsUsecase>(),
        registerResponsibilityConsentUsecase:
            locator<RegisterResponsibilityConsentUsecase>(),
        openFundingPaymentLinkUsecase: locator<OpenFundingPaymentLinkUsecase>(),
        getConfidentialSepaFundingAvailabilityUsecase:
            locator<GetConfidentialSepaFundingAvailabilityUsecase>(),
      ),
    );
  }
}
