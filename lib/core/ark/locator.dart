import 'package:bb_mobile/core/ark/usecases/create_ark_secret_usecase.dart';
import 'package:bb_mobile/core/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core/ark/usecases/get_ark_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/locator.dart';

class ArkLocator {
  static void setup() {
    locator.registerFactory<CreateArkSecretUsecase>(
      () => CreateArkSecretUsecase(bip85Repository: locator<Bip85Repository>()),
    );

    locator.registerFactory<FetchArkSecretUsecase>(
      () => FetchArkSecretUsecase(
        bip85Repository: locator<Bip85Repository>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );
    locator.registerFactory<GetArkWalletUsecase>(
      () => GetArkWalletUsecase(
        fetchArkSecretUsecase: locator<FetchArkSecretUsecase>(),
      ),
    );
  }
}
