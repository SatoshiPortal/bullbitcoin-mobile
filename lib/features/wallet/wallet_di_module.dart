import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';

class WalletDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<GetUnconfirmedIncomingBalanceUsecase>(
      () => GetUnconfirmedIncomingBalanceUsecase(
        settingsRepository: sl(),
        mainnetBoltzSwapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<WalletBloc>(
      () => WalletBloc(
        getArkWalletUsecase: sl(),
        checkArkWalletSetupUsecase: sl(),
        getWalletsUsecase: sl(),
        checkWalletSyncingUsecase: sl(),
        watchStartedWalletSyncsUsecase: sl(),
        watchFinishedWalletSyncsUsecase: sl(),
        watchElectrumSyncResultsUsecase: sl(),
        restartSwapWatcherUsecase: sl(),
        initializeTorUsecase: sl(),
        checkForTorInitializationOnStartupUsecase: sl(),
        getUnconfirmedIncomingBalanceUsecase: sl(),
        getAutoSwapSettingsUsecase: sl(),
        saveAutoSwapSettingsUsecase: sl(),
        autoSwapExecutionUsecase: sl(),
        deleteWalletUsecase: sl(),
      ),
    );
  }
}
