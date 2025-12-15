import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/features/legacy_seed_view/presentation/legacy_seed_view_cubit.dart';
import 'package:bb_mobile/locator.dart';

class LegacySeedViewLocator {
  static void setup() {
    locator.registerFactory<LegacySeedViewCubit>(
      () => LegacySeedViewCubit(
        getOldSeedsUsecase: locator<GetOldSeedsUsecase>(),
      ),
    );
  }
}
