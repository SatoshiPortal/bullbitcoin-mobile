import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';

class ReceiveDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<CreateReceiveSwapUsecase>(
      () => CreateReceiveSwapUsecase(
        walletRepository: sl(),
        swapRepository: sl<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: sl<BoltzSwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
        seedRepository: sl(),
        getReceiveAddressUsecase: sl(),
        labelsFacade: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactoryParam<ReceiveBloc, Wallet?, void>(
      (wallet, _) => ReceiveBloc(
        getWalletsUsecase: sl(),
        getAvailableCurrenciesUsecase: sl(),
        getSettingsUsecase: sl(),
        convertSatsToCurrencyAmountUsecase: sl(),
        getReceiveAddressUsecase: sl(),
        getAddressAtIndexUsecase: sl(),
        createReceiveSwapUsecase: sl(),
        receiveWithPayjoinUsecase: sl(),
        broadcastOriginalTransactionUsecase: sl(),
        watchPayjoinUsecase: sl(),
        watchWalletTransactionByAddressUsecase: sl(),
        watchSwapUsecase: sl(),
        labelsFacade: sl(),
        getSwapLimitsUsecase: sl(),
        wallet: wallet,
      ),
    );
  }
}
