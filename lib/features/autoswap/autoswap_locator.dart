import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';

class AutoSwapLocator {
  static void setup() {
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
