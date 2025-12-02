import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_from_secure_storage_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/locator.dart';

class AllSeedViewLocator {
  static void setup() {
    locator.registerFactory<AllSeedViewCubit>(
      () => AllSeedViewCubit(
        getAllSeedsFromSecureStorageUsecase:
            locator<GetAllSeedsFromSecureStorageUsecase>(),
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        deleteSeedUsecase: locator<DeleteSeedUsecase>(),
        processAndSeparateSeedsUsecase:
            locator<ProcessAndSeparateSeedsUsecase>(),
      ),
    );
  }
}
