import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/default_wallets_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/secure_file_upload_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/default_wallets_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/secure_file_upload_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/toggle_email_notifications_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_secure_file_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_transactions_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:get_it/get_it.dart';

class ExchangeSettingsLocator {
  static void registerRepositories(GetIt locator) {
    // Default Wallets Repository - mainnet
    locator.registerLazySingleton<DefaultWalletsRepository>(
      () => DefaultWalletsRepositoryImpl(
        apiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetDefaultWalletsRepository',
    );

    // Default Wallets Repository - testnet
    locator.registerLazySingleton<DefaultWalletsRepository>(
      () => DefaultWalletsRepositoryImpl(
        apiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetDefaultWalletsRepository',
    );

    // Secure File Upload Repository - mainnet
    locator.registerLazySingleton<SecureFileUploadRepository>(
      () => SecureFileUploadRepositoryImpl(
        apiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetSecureFileUploadRepository',
    );

    // Secure File Upload Repository - testnet
    locator.registerLazySingleton<SecureFileUploadRepository>(
      () => SecureFileUploadRepositoryImpl(
        apiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetSecureFileUploadRepository',
    );
  }

  static void registerUseCases(GetIt locator) {
    // Default Wallets Use Cases
    locator.registerFactory<GetDefaultWalletsUsecase>(
      () => GetDefaultWalletsUsecase(
        mainnetDefaultWalletsRepository: locator<DefaultWalletsRepository>(
          instanceName: 'mainnetDefaultWalletsRepository',
        ),
        testnetDefaultWalletsRepository: locator<DefaultWalletsRepository>(
          instanceName: 'testnetDefaultWalletsRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SaveDefaultWalletUsecase>(
      () => SaveDefaultWalletUsecase(
        mainnetDefaultWalletsRepository: locator<DefaultWalletsRepository>(
          instanceName: 'mainnetDefaultWalletsRepository',
        ),
        testnetDefaultWalletsRepository: locator<DefaultWalletsRepository>(
          instanceName: 'testnetDefaultWalletsRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<DeleteDefaultWalletUsecase>(
      () => DeleteDefaultWalletUsecase(
        mainnetDefaultWalletsRepository: locator<DefaultWalletsRepository>(
          instanceName: 'mainnetDefaultWalletsRepository',
        ),
        testnetDefaultWalletsRepository: locator<DefaultWalletsRepository>(
          instanceName: 'testnetDefaultWalletsRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // Order Stats Use Case
    locator.registerFactory<GetOrderStatsUsecase>(
      () => GetOrderStatsUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // Secure File Upload Use Case
    locator.registerFactory<UploadSecureFileUsecase>(
      () => UploadSecureFileUsecase(
        mainnetSecureFileUploadRepository: locator<SecureFileUploadRepository>(
          instanceName: 'mainnetSecureFileUploadRepository',
        ),
        testnetSecureFileUploadRepository: locator<SecureFileUploadRepository>(
          instanceName: 'testnetSecureFileUploadRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // Toggle Email Notifications Use Case
    locator.registerFactory<ToggleEmailNotificationsUsecase>(
      () => ToggleEmailNotificationsUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }

  static void registerCubits(GetIt locator) {
    locator.registerFactory<DefaultWalletsCubit>(
      () => DefaultWalletsCubit(
        getDefaultWalletsUsecase: locator<GetDefaultWalletsUsecase>(),
        saveDefaultWalletUsecase: locator<SaveDefaultWalletUsecase>(),
        deleteDefaultWalletUsecase: locator<DeleteDefaultWalletUsecase>(),
      ),
    );

    locator.registerFactory<FileUploadCubit>(
      () => FileUploadCubit(
        uploadSecureFileUsecase: locator<UploadSecureFileUsecase>(),
      ),
    );

    locator.registerFactory<StatisticsCubit>(
      () => StatisticsCubit(
        getOrderStatsUsecase: locator<GetOrderStatsUsecase>(),
      ),
    );

    locator.registerFactory<ExchangeTransactionsCubit>(
      () => ExchangeTransactionsCubit(
        listAllOrdersUsecase: locator<ListAllOrdersUsecase>(),
      ),
    );
  }

  static void setup(GetIt locator) {
    registerRepositories(locator);
    registerUseCases(locator);
    registerCubits(locator);
  }
}






