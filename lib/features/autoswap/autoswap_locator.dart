import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:bb_mobile/features/autoswap/presentation/swap_provider_availability_cubit.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:get_it/get_it.dart';

class AutoSwapLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
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
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<AutoSwapSettingsCubit>(
      () => AutoSwapSettingsCubit(
        loadAutoswapSettingsUsecase: locator<LoadAutoswapSettingsUsecase>(),
        saveAutoswapSettingsUsecase: locator<SaveAutoswapSettingsUsecase>(),
      ),
    );
    locator.registerFactory<SwapProviderAvailabilityCubit>(
      () => SwapProviderAvailabilityCubit(
        getAutoSwapSettingsUsecase: locator<GetAutoSwapSettingsUsecase>(),
        swapFacade: locator<SwapFacade>(),
      ),
    );
  }
}
