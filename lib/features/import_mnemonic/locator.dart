import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:get_it/get_it.dart';

class ImportMnemonicLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CheckDuplicateMnemonicUsecase>(
      () => CheckDuplicateMnemonicUsecase(
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<ImportWalletUsecase>(
      () => ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
        seedRepository: locator<SeedRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    registerCubit(locator);
  }

  static void registerCubit(GetIt locator) {
    locator.registerFactory<ImportMnemonicCubit>(
      () => ImportMnemonicCubit(
        importWalletUsecase: locator<ImportWalletUsecase>(),
        checkWalletUsecase: locator<TheDirtyUsecase>(),
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
      ),
    );
  }
}
