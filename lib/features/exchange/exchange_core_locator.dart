import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:get_it/get_it.dart';

class ExchangeLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<Exchange>(
      () => Exchange.open(
        mainnetEndpoint: Uri.parse(ApiServiceConstants.bbApiUrl),
        testnetEndpoint: Uri.parse(ApiServiceConstants.bbApiTestUrl),
        paymentReturnUrl: Uri.parse(ApiServiceConstants.bbAppUrl),
        access: locator<ExchangeAccessLifecycle>(),
        kyc: (
          mainnetUrl: Uri.parse(ApiServiceConstants.bbKycUrl),
          testnetUrl: Uri.parse(ApiServiceConstants.bbKycTestUrl),
          preferences: locator<Preferences>(),
        ),
        readSession: () => readLegacyExchangeSession(
          preferences: locator<Preferences>(),
          readEpoch: () => locator<ExchangeAccessLifecycle>().epoch,
          readKey: locator<ExchangeCredentials>().readActiveApiKey,
        ),
        notifications: (
          readEnvironment: () =>
              readLegacyExchangeEnvironment(locator<Preferences>()),
          readKey: ({required isTestnet}) => locator<ExchangeCredentials>()
              .readActiveApiKey(isTestnet: isTestnet),
        ),
      ),
      dispose: (exchange) => exchange.close(),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<ExchangeCredentials>(
      () => ExchangeCredentials.open(locator<Secrets>().exchangeKeychain),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<GetExchangeUserSummaryUsecase>(
      () => GetExchangeUserSummaryUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
      ),
    );

    locator.registerFactory<GetOrderUsecase>(
      () => GetOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
      ),
    );

    locator.registerFactory<ListAllOrdersUsecase>(
      () => ListAllOrdersUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
      ),
    );
  }
}
