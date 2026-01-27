import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';

class BitcoinPriceDiModule implements FeatureDiModule {
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
    sl.registerFactory<BitcoinPriceBloc>(
      () => BitcoinPriceBloc(
        getAvailableCurrenciesUsecase: sl(),
        getSettingsUsecase: sl(),
        convertSatsToCurrencyAmountUsecase: sl(),
        watchCurrencyChangesUsecase: sl(),
      ),
    );

    sl.registerFactory<PriceChartCubit>(
      () => PriceChartCubit(
        getPriceHistoryUsecase: sl(),
        refreshPriceHistoryUsecase: sl(),
        getSettingsUsecase: sl(),
      ),
    );
  }
}
