import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';

class SendDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<DetectBitcoinStringUsecase>(
      () => DetectBitcoinStringUsecase(),
    );
    sl.registerFactory<PrepareBitcoinSendUsecase>(
      () => PrepareBitcoinSendUsecase(
        payjoinRepository: sl(),
        bitcoinWalletRepository: sl(),
      ),
    );
    sl.registerFactory<PrepareLiquidSendUsecase>(
      () => PrepareLiquidSendUsecase(
        liquidWalletRepository: sl(),
      ),
    );
    sl.registerFactory<SignLiquidTxUsecase>(
      () => SignLiquidTxUsecase(
        liquidWalletRepository: sl(),
      ),
    );
    sl.registerFactory<SignBitcoinTxUsecase>(
      () => SignBitcoinTxUsecase(
        bitcoinWalletRepository: sl(),
      ),
    );
    sl.registerFactory<CreateSendSwapUsecase>(
      () => CreateSendSwapUsecase(
        swapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        walletRepository: sl(),
        seedRepository: sl(),
      ),
    );
    sl.registerFactory<UpdatePaidSendSwapUsecase>(
      () => UpdatePaidSendSwapUsecase(
        swapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    sl.registerFactory<SelectBestWalletUsecase>(
      () => SelectBestWalletUsecase(),
    );
    sl.registerFactory<CalculateBitcoinAbsoluteFeesUsecase>(
      () => CalculateBitcoinAbsoluteFeesUsecase(
        bitcoinWalletRepository: sl(),
      ),
    );
    sl.registerFactory<CalculateLiquidAbsoluteFeesUsecase>(
      () => CalculateLiquidAbsoluteFeesUsecase(
        liquidWalletRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactoryParam<SendCubit, Wallet?, void>(
      (wallet, _) => SendCubit(
        wallet: wallet,
        bestWalletUsecase: sl(),
        detectBitcoinStringUsecase: sl(),
        getSettingsUsecase: sl(),
        convertSatsToCurrencyAmountUsecase: sl(),
        getNetworkFeesUsecase: sl(),
        getAvailableCurrenciesUsecase: sl(),
        getWalletUtxosUsecase: sl(),
        prepareBitcoinSendUsecase: sl(),
        prepareLiquidSendUsecase: sl(),
        signBitcoinTxUsecase: sl(),
        signLiquidTxUsecase: sl(),
        broadcastBitcoinTxUsecase: sl(),
        broadcastLiquidTxUsecase: sl(),
        getWalletsUsecase: sl(),
        getWalletUsecase: sl(),
        createSendSwapUsecase: sl(),
        updatePaidSendSwapUsecase: sl(),
        getSwapLimitsUsecase: sl(),
        watchSwapUsecase: sl(),
        sendWithPayjoinUsecase: sl(),
        watchFinishedWalletSyncsUsecase: sl(),
        decodeInvoiceUsecase: sl(),
        calculateLiquidAbsoluteFeesUsecase: sl(),
        createChainSwapToExternalUsecase: sl(),
        watchWalletTransactionByTxIdUsecase: sl(),
        calculateBitcoinAbsoluteFeesUsecase: sl(),
        updateSendSwapLockupFeesUsecase: sl(),
        verifyChainSwapAmountSendUsecase: sl(),
      ),
    );
  }
}
