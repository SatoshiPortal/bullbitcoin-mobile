import 'package:address_view/address_view.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/autoswap/autoswap_watcher.dart';
import 'package:bb_mobile/features/autoswap/data/boltz_autoswap_provider.dart';
import 'package:bb_mobile/features/autoswap/data/exchange_autoswap_provider.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:swaps/swaps.dart'
    show
        AutoSwapSettings,
        Autoswap,
        AutoswapSettingsUnavailableFailure,
        AutoswapUnsupportedNetworkFailure,
        CreateLiquidToBitcoinSwapUsecase,
        DropPendingSwapLockupUsecase,
        GetSwapLimitsAndFeesUsecase,
        RecordPendingSwapLockupUsecase,
        RecordSwapLockupUsecase,
        SwapRouting,
        SwapsUnsupportedNetworkFailure;
import 'package:get_it/get_it.dart';
import 'package:spend/spend.dart';

class AutoSwapLocator {
  static void setup(GetIt locator) {
    registerProviders(locator);
    registerUsecases(locator);
    registerBlocs(locator);
    registerWatchers(locator);
  }

  static void registerProviders(GetIt locator) {
    locator.registerLazySingleton<BoltzAutoswapProvider>(
      () => BoltzAutoswapProvider(
        locator<GetSwapLimitsAndFeesUsecase>(),
        locator<CreateLiquidToBitcoinSwapUsecase>(),
        locator<RecordSwapLockupUsecase>(),
        locator<RecordPendingSwapLockupUsecase>(),
        locator<DropPendingSwapLockupUsecase>(),
        locator<WalletRepository>(),
        locator<Preferences>(),
        locator<Spend>(),
        locator<AddressView>(),
        locator<Labels>(),
      ),
    );
    locator.registerLazySingleton<ExchangeAutoswapProvider>(
      () => ExchangeAutoswapProvider(
        locator<WalletRepository>(),
        locator<Preferences>(),
        locator<Spend>(),
        locator<AddressView>(),
        locator<SwapFacade>(),
        locator<Labels>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<LoadAutoswapSettingsUsecase>(
      () => LoadAutoswapSettingsUsecase(
        autoSwapSettings: locator<AutoSwapSettings>(),
        getSettingsUsecase: locator<Preferences>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<SaveAutoswapSettingsUsecase>(
      () => SaveAutoswapSettingsUsecase(locator<AutoSwapSettings>()),
    );
    locator.registerFactory<Autoswap>(
      () => Autoswap.open(
        readSettings: () async =>
            (await locator<AutoSwapSettings>().readAutoSwap()).mapErr(
              (failure) => switch (failure) {
                SwapsUnsupportedNetworkFailure() =>
                  const AutoswapUnsupportedNetworkFailure(),
                _ => AutoswapSettingsUnavailableFailure(
                  failure.runtimeType.toString(),
                ),
              },
            ),
        resolveRoute: locator<SwapRouting>().resolveRoute,
        runBoltz: locator<BoltzAutoswapProvider>().execute,
        runExchange: locator<ExchangeAutoswapProvider>().execute,
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
        locator<Autoswap>(),
      ),
      dispose: (watcher) => watcher.dispose(),
    );
  }
}
