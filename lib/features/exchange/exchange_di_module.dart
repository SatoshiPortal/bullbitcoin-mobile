import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';

class ExchangeDiModule implements FeatureDiModule {
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
    sl.registerLazySingleton<ExchangeCubit>(
      () => ExchangeCubit(
        saveExchangeApiKeyUsecase: sl(),
        getExchangeUserSummaryUsecase: sl(),
        saveUserPreferencesUsecase: sl(),
        deleteExchangeApiKeyUsecase: sl(),
      ),
    );
  }
}
