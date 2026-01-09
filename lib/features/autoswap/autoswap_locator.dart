import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class AutoSwapLocator {
  static void setup(GetIt locator) {
    // Register the cubit
    locator.registerFactory<AutoSwapSettingsCubit>(
      () => AutoSwapSettingsCubit(
        getAutoSwapSettingsUsecase: locator<GetAutoSwapSettingsUsecase>(),
        saveAutoSwapSettingsUsecase: locator<SaveAutoSwapSettingsUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
