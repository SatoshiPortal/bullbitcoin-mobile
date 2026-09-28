import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_recipient_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:get_it/get_it.dart';

class DefaultWalletsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<ExchangeRecipientRepository>(
      () => ExchangeRecipientRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnet',
    );

    locator.registerLazySingleton<ExchangeRecipientRepository>(
      () => ExchangeRecipientRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnet',
    );

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
