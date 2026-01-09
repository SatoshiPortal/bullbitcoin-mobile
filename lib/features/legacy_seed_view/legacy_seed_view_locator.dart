import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/features/legacy_seed_view/presentation/legacy_seed_view_cubit.dart';
import 'package:get_it/get_it.dart';

class LegacySeedViewLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<LegacySeedViewCubit>(
      () => LegacySeedViewCubit(
        getOldSeedsUsecase: locator<GetOldSeedsUsecase>(),
      ),
    );
  }
}
