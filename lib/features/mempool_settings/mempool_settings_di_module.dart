import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';

class MempoolSettingsDiModule implements FeatureDiModule {
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
    sl.registerFactory<MempoolSettingsCubit>(
      () => MempoolSettingsCubit(
        loadDataUsecase: sl(),
        setCustomServerUsecase: sl(),
        deleteCustomServerUsecase: sl(),
        updateSettingsUsecase: sl(),
      ),
    );
  }
}
