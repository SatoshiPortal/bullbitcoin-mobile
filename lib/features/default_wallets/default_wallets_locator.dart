import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/default_wallets/data/bbx_api_exchange_recipient_repository.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bbx_api/bbx_api.dart' show BbxApiClient;
import 'package:get_it/get_it.dart';

class DefaultWalletsLocator {
  static void setup(GetIt locator) {
    for (final environment in ['mainnet', 'testnet']) {
      locator.registerLazySingleton<ExchangeRecipientRepository>(
        () => BbxApiExchangeRecipientRepository(
          api: locator<BbxApiClient>(
            instanceName: '${environment}BbxApiClient',
          ),
        ),
        instanceName: environment,
      );
    }

    locator.registerLazySingleton<GetDefaultWalletsUsecase>(
      () => GetDefaultWalletsUsecase(
        mainnetRepository: locator<ExchangeRecipientRepository>(
          instanceName: 'mainnet',
        ),
        testnetRepository: locator<ExchangeRecipientRepository>(
          instanceName: 'testnet',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<SaveDefaultWalletUsecase>(
      () => SaveDefaultWalletUsecase(
        mainnetRepository: locator<ExchangeRecipientRepository>(
          instanceName: 'mainnet',
        ),
        testnetRepository: locator<ExchangeRecipientRepository>(
          instanceName: 'testnet',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<DeleteDefaultWalletUsecase>(
      () => DeleteDefaultWalletUsecase(
        mainnetRepository: locator<ExchangeRecipientRepository>(
          instanceName: 'mainnet',
        ),
        testnetRepository: locator<ExchangeRecipientRepository>(
          instanceName: 'testnet',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<DefaultWalletsFacade>(
      () => DefaultWalletsFacade(
        getDefaultWalletsUsecase: locator<GetDefaultWalletsUsecase>(),
        saveDefaultWalletUsecase: locator<SaveDefaultWalletUsecase>(),
        deleteDefaultWalletUsecase: locator<DeleteDefaultWalletUsecase>(),
      ),
    );
  }
}
