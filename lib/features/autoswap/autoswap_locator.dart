import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/autoswap/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/features/autoswap/domain/auto_swap_settings_repository.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/watch_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/autoswap/autoswap_watcher.dart';
import 'package:bb_mobile/features/autoswap/data/exchange_autoswap_provider.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class AutoSwapLocator {
  static void setup(GetIt locator) {
    registerProviders(locator);
    registerUsecases(locator);
    registerBlocs(locator);
    registerWatchers(locator);
  }

  static void registerProviders(GetIt locator) {
    locator.registerLazySingleton<AutoSwapSettingsRepository>(
      () => AutoSwapSettingsRepositoryImpl(
        locator<SqliteDatabase>(),
        locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetAutoSwapSettingsUsecase>(
      () => GetAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<SaveAutoSwapSettingsUsecase>(
      () => SaveAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchAutoSwapSettingsUsecase>(
      () => WatchAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<DisableAutoswapWarningUsecase>(
      () => DisableAutoswapWarningUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<DisableAutoswapUsecase>(
      () => DisableAutoswapUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<AutoswapProviderPort>(
      () => ExchangeAutoswapProvider(
        locator<WalletRepository>(),
        locator<SettingsRepository>(),
        locator<LiquidWalletRepository>(),
        locator<GetReceiveAddressUsecase>(),
        locator<BroadcastLiquidTransactionUsecase>(),
        locator<SwapFacade>(),
        locator<LabelsFacade>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<LoadAutoswapSettingsUsecase>(
      () => LoadAutoswapSettingsUsecase(
        getAutoSwapSettingsUsecase: locator<GetAutoSwapSettingsUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<SaveAutoswapSettingsUsecase>(
      () => SaveAutoswapSettingsUsecase(
        saveAutoSwapSettingsUsecase: locator<SaveAutoSwapSettingsUsecase>(),
      ),
    );
    locator.registerFactory<ExecuteAutoswapUsecase>(
      () => ExecuteAutoswapUsecase(
        locator<GetAutoSwapSettingsUsecase>(),
        locator<AutoswapProviderPort>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<AutoSwapSettingsCubit>(
      () => AutoSwapSettingsCubit(
        loadAutoswapSettingsUsecase: locator<LoadAutoswapSettingsUsecase>(),
        saveAutoswapSettingsUsecase: locator<SaveAutoswapSettingsUsecase>(),
      ),
    );
  }

  static void registerWatchers(GetIt locator) {
    locator.registerLazySingleton<AutoswapWatcher>(
      () => AutoswapWatcher(
        locator<WatchFinishedWalletSyncsUsecase>(),
        locator<ExecuteAutoswapUsecase>(),
      ),
      dispose: (watcher) => watcher.dispose(),
    );
  }
}
