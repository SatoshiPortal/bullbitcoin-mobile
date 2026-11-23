import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:get_it/get_it.dart';

import 'domain/repositories/exchange_access_repository.dart';

class ExchangeLocator {
  /// Supplies point-of-use credentials to legacy recipient clients. The
  /// Exchange package owns the credential record; Secrets owns the keychain.
  static Future<Result<String?, bbx.BbxFailure>> _readActiveApiKey(
    GetIt locator, {
    required bool isTestnet,
  }) async {
    final result = await locator<ExchangeCredentials>().readActiveApiKey(
      isTestnet: isTestnet,
    );
    return switch (result) {
      Ok(:final value) => Ok(value),
      Err() => const Err(bbx.BbxCredentialUnavailableFailure()),
    };
  }

  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<Exchange>(
      () => Exchange.open(
        mainnetEndpoint: Uri.parse(ApiServiceConstants.bbApiUrl),
        testnetEndpoint: Uri.parse(ApiServiceConstants.bbApiTestUrl),
        paymentReturnUrl: Uri.parse(ApiServiceConstants.bbAppUrl),
        readSession: () => readLegacyExchangeSession(
          preferences: locator<Preferences>(),
          readEpoch: () => locator<ExchangeAccessRepository>().epoch,
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
    for (final isTestnet in [false, true]) {
      final environment = isTestnet ? 'testnet' : 'mainnet';
      locator.registerLazySingleton<bbx.Bbx>(
        () => bbx.Bbx.open(
          endpoint: isTestnet
              ? ApiServiceConstants.bbApiTestUrl
              : ApiServiceConstants.bbApiUrl,
          readActiveApiKey: () =>
              _readActiveApiKey(locator, isTestnet: isTestnet),
          timeouts: bbx.BbxTimeouts.standard,
        ),
        instanceName: '${environment}BbxApiClient',
      );
      locator.registerLazySingleton<bbx.Bbx>(
        () => bbx.Bbx.open(
          endpoint: isTestnet
              ? ApiServiceConstants.bbApiTestUrl
              : ApiServiceConstants.bbApiUrl,
          readActiveApiKey: () =>
              _readActiveApiKey(locator, isTestnet: isTestnet),
        ),
        instanceName: '${environment}BbxApiClientWithoutTimeout',
      );
    }
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
  }
}
