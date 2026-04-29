import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/exchange_environment_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/settings_exchange_environment_adapter.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/bullbitcoin_api_funding_gateway.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/delegating_funding_gateway.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class FundExchangeLocator {
  static void setup(GetIt locator) {
    registerDrivenInterfaceAdapters(locator);
    registerApplicationServicesAndUseCases(locator);
    registerDrivingInterfaceAdapters(locator);
  }

  static void registerDrivenInterfaceAdapters(GetIt locator) {
    locator.registerLazySingleton<ExchangeEnvironmentPort>(
      () => SettingsExchangeEnvironmentAdapter(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
    );

    locator.registerLazySingleton<FundingGatewayPort>(
      () => DelegatingFundingGateway(
        bullbitcoinFundingGateway: BullBitcoinApiFundingGateway(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiClient',
          ),
        ),
        bullBitcoinTestnetFundingGateway: BullBitcoinApiFundingGateway(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
        exchangeEnvironment: locator<ExchangeEnvironmentPort>(),
      ),
    );
  }

  static void registerApplicationServicesAndUseCases(GetIt locator) {
    locator.registerFactory<ListFundingInstitutionsUsecase>(
      () => ListFundingInstitutionsUsecase(
        fundingGateway: locator<FundingGatewayPort>(),
      ),
    );

    locator.registerFactory<GetFundingDetailsUsecase>(
      () => GetFundingDetailsUsecase(
        fundingGateway: locator<FundingGatewayPort>(),
      ),
    );

    locator.registerFactory<RegisterResponsibilityConsentUsecase>(
      () => RegisterResponsibilityConsentUsecase(
        fundingGateway: locator<FundingGatewayPort>(),
      ),
    );
  }

  static void registerDrivingInterfaceAdapters(GetIt locator) {
    locator.registerFactory<FundExchangeBloc>(
      () => FundExchangeBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        listFundingInstitutionsUsecase:
            locator<ListFundingInstitutionsUsecase>(),
        getFundingDetailsUsecase: locator<GetFundingDetailsUsecase>(),
        registerResponsibilityConsentUsecase:
            locator<RegisterResponsibilityConsentUsecase>(),
      ),
    );
  }
}
