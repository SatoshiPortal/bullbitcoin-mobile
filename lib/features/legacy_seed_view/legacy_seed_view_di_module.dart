import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/legacy_seed_view/presentation/legacy_seed_view_cubit.dart';

class LegacySeedViewDiModule implements FeatureDiModule {
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
    sl.registerFactory<LegacySeedViewCubit>(
      () => LegacySeedViewCubit(
        getOldSeedsUsecase: sl(),
      ),
    );
  }
}
