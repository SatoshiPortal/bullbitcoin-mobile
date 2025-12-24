import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';

class BuyDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {}

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<BuyBloc>(
      () => BuyBloc(
        getWalletsUsecase: sl(),
        getReceiveAddressUsecase: sl(),
        getExchangeUserSummaryUsecase: sl(),
        confirmBuyOrderUsecase: sl(),
        createBuyOrderUsecase: sl(),
        getNetworkFeesUsecase: sl(),
        refreshBuyOrderUsecase: sl(),
        convertSatsToCurrencyAmountUsecase: sl(),
        accelerateBuyOrderUsecase: sl(),
        getSettingsUsecase: sl(),
      ),
    );
  }
}
