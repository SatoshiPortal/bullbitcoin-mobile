import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show SeedReferences;
import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/get_all_secrets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/separate_secrets_usecase.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:get_it/get_it.dart';

class AllSeedViewLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<AllSeedViewCubit>(
      () => AllSeedViewCubit(
        getAllSecretsUsecase: GetAllSecretsUsecase(secrets: locator<Secrets>()),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        deleteSecretUsecase: DeleteSecretUsecase(
          secrets: locator<Secrets>(),
          seedReferences: locator<SeedReferences>(),
        ),
        separateSecretsUsecase: const SeparateSecretsUsecase(),
        getSwapMasterKeyUsecase: locator<GetSwapMasterKeyUsecase>(),
        getSwapMnemonicUsecase: locator<GetSwapMnemonicUsecase>(),
        deleteSwapMasterKeyUsecase: locator<DeleteSwapMasterKeyUsecase>(),
      ),
    );
  }
}
