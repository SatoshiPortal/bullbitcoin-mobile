import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/get_all_secrets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/separate_secrets_usecase.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_mnemonic_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
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
          walletRepository: locator<WalletRepository>(),
        ),
        separateSecretsUsecase: const SeparateSecretsUsecase(),
        getSwapMasterKeyUsecase: locator<GetSwapMasterKeyUsecase>(),
        getSwapMnemonicUsecase: locator<GetSwapMnemonicUsecase>(),
        deleteSwapMasterKeyUsecase: locator<DeleteSwapMasterKeyUsecase>(),
      ),
    );
  }
}
