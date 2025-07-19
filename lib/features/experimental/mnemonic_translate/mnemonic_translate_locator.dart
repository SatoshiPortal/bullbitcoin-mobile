import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/experimental/mnemonic_translate/domain/usecases/get_default_mnemonic_usecase.dart';
import 'package:bb_mobile/locator.dart';

class MnemonicTranslateLocator {
  static void setup() {
    registerUsecases();
  }

  static void registerUsecases() {
    locator.registerFactory<GetDefaultMnemonicUsecase>(
      () => GetDefaultMnemonicUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
  }
}
