import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_kyc_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_stats_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_recipient_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:get_it/get_it.dart';

class ExchangeSettingsLocator {
  static void setup(GetIt locator) {
    _registerRepositories(locator);
    _registerUsecases(locator);
    _registerCubits(locator);
  }

  static void _registerRepositories(GetIt locator) {
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

    locator.registerLazySingleton<ExchangeKycRepository>(
      () => ExchangeKycRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnet',
    );

    locator.registerLazySingleton<ExchangeKycRepository>(
      () => ExchangeKycRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnet',
    );

    locator.registerLazySingleton<ExchangeOrderStatsRepository>(
      () => ExchangeOrderStatsRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnet',
    );

    locator.registerLazySingleton<ExchangeOrderStatsRepository>(
      () => ExchangeOrderStatsRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnet',
    );
  }

  static void _registerUsecases(GetIt locator) {
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

    locator.registerLazySingleton<UploadKycDocumentUsecase>(
      () => UploadKycDocumentUsecase(
        mainnetRepository: locator<ExchangeKycRepository>(
          instanceName: 'mainnet',
        ),
        testnetRepository: locator<ExchangeKycRepository>(
          instanceName: 'testnet',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<GetOrderStatsUsecase>(
      () => GetOrderStatsUsecase(
        mainnetRepository: locator<ExchangeOrderStatsRepository>(
          instanceName: 'mainnet',
        ),
        testnetRepository: locator<ExchangeOrderStatsRepository>(
          instanceName: 'testnet',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }

  static void _registerCubits(GetIt locator) {
    locator.registerFactory<DefaultWalletsCubit>(
      () => DefaultWalletsCubit(
        getDefaultWalletsUsecase: locator<GetDefaultWalletsUsecase>(),
        saveDefaultWalletUsecase: locator<SaveDefaultWalletUsecase>(),
        deleteDefaultWalletUsecase: locator<DeleteDefaultWalletUsecase>(),
      ),
    );

    locator.registerFactory<FileUploadCubit>(
      () => FileUploadCubit(
        uploadKycDocumentUsecase: locator<UploadKycDocumentUsecase>(),
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );

    locator.registerFactory<StatisticsCubit>(
      () => StatisticsCubit(
        getOrderStatsUsecase: locator<GetOrderStatsUsecase>(),
      ),
    );
  }
}
