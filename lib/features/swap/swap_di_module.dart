import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';

class SwapDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    // NOTE: Many use cases here are likely already registered in send_di_module
    // Commenting them out to avoid duplicates, but leaving as reference

    // sl.registerFactory<PrepareBitcoinSendUsecase>(
    //   () => PrepareBitcoinSendUsecase(
    //     payjoinRepository: sl(),
    //     bitcoinWalletRepository: sl(),
    //   ),
    // );
    // sl.registerFactory<PrepareLiquidSendUsecase>(
    //   () => PrepareLiquidSendUsecase(
    //     liquidWalletRepository: sl(),
    //   ),
    // );
    // sl.registerFactory<SignLiquidTxUsecase>(
    //   () => SignLiquidTxUsecase(
    //     liquidWalletRepository: sl(),
    //   ),
    // );
    // sl.registerFactory<SignBitcoinTxUsecase>(
    //   () => SignBitcoinTxUsecase(
    //     bitcoinWalletRepository: sl(),
    //   ),
    // );
    // sl.registerFactory<CalculateBitcoinAbsoluteFeesUsecase>(
    //   () => CalculateBitcoinAbsoluteFeesUsecase(
    //     bitcoinWalletRepository: sl(),
    //   ),
    // );
    // sl.registerFactory<CalculateLiquidAbsoluteFeesUsecase>(
    //   () => CalculateLiquidAbsoluteFeesUsecase(
    //     liquidWalletRepository: sl(),
    //   ),
    // );
    // sl.registerFactory<DetectBitcoinStringUsecase>(
    //   () => DetectBitcoinStringUsecase(),
    // );

    sl.registerFactory<UpdateSendSwapLockupFeesUsecase>(
      () => UpdateSendSwapLockupFeesUsecase(
        swapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: sl<BoltzSwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    sl.registerFactory<VerifyChainSwapAmountSendUsecase>(
      () => VerifyChainSwapAmountSendUsecase(walletRepository: sl()),
    );

    sl.registerFactory<CreateChainSwapToExternalUsecase>(
      () => CreateChainSwapToExternalUsecase(
        walletRepository: sl(),
        seedRepository: sl(),
        swapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: sl<BoltzSwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<TransferBloc>(
      () => TransferBloc(
        getSettingsUsecase: sl(),
        getWalletsUsecase: sl(),
        getSwapLimitsUsecase: sl(),
        getNetworkFeesUsecase: sl(),
        prepareBitcoinSendUsecase: sl(),
        prepareLiquidSendUsecase: sl(),
        calculateBitcoinAbsoluteFeesUsecase: sl(),
        calculateLiquidAbsoluteFeesUsecase: sl(),
        createChainSwapUsecase: sl(),
        createChainSwapToExternalUsecase: sl(),
        watchSwapUsecase: sl(),
        getWalletUsecase: sl(),
        signBitcoinTxUsecase: sl(),
        signLiquidTxUsecase: sl(),
        broadcastBitcoinTxUsecase: sl(),
        broadcastLiquidTxUsecase: sl(),
        updatePaidChainSwapUsecase: sl(),
        updateSendSwapLockupFeesUsecase: sl(),
        verifyChainSwapAmountSendUsecase: sl(),
        detectBitcoinStringUsecase: sl(),
        getReceiveAddressUsecase: sl(),
        getWalletUtxosUsecase: sl(),
        convertSatsToCurrencyAmountUsecase: sl(),
      ),
    );
  }
}
