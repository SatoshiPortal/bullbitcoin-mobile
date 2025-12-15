import 'package:bb_mobile/core_deprecated/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/locator.dart';

class AllSeedViewLocator {
  static void setup() {
    locator.registerFactory<AllSeedViewCubit>(
      () => AllSeedViewCubit(
        getAllSeedsUsecase: locator<GetAllSeedsUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        deleteSeedUsecase: locator<DeleteSeedUsecase>(),
        processAndSeparateSeedsUsecase:
            locator<ProcessAndSeparateSeedsUsecase>(),
      ),
    );
  }
}
