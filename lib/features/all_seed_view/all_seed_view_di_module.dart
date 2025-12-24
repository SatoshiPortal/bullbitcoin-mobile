import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';

class AllSeedViewDiModule implements FeatureDiModule {
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
    sl.registerFactory<AllSeedViewCubit>(
      () => AllSeedViewCubit(
        getAllSeedsUsecase: sl(),
        getWalletsUsecase: sl(),
        deleteSeedUsecase: sl(),
        processAndSeparateSeedsUsecase: sl(),
      ),
    );
  }
}
