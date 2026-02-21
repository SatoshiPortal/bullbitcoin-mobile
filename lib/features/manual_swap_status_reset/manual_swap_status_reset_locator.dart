import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/manual_swap_status_reset/domain/usecases/manual_swap_status_reset_usecase.dart';
import 'package:bb_mobile/features/manual_swap_status_reset/presentation/cubit/manual_swap_status_reset_cubit.dart';
import 'package:get_it/get_it.dart';

class ManualSwapStatusResetLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ManualSwapStatusResetUsecase>(
      () => ManualSwapStatusResetUsecase(
        mainnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetRepository: locator<BoltzSwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<ManualSwapStatusResetCubit>(
      () => ManualSwapStatusResetCubit(
        manualSwapStatusResetUsecase: locator<ManualSwapStatusResetUsecase>(),
      ),
    );
  }
}
