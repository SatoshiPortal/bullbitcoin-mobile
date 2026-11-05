import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:get_it/get_it.dart';

class ImportMnemonicLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CheckDuplicateMnemonicUsecase>(
      () => CheckDuplicateMnemonicUsecase(secrets: locator<Secrets>()),
    );
    locator.registerFactory<ImportWalletUsecase>(
      () => ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
        secrets: locator<Secrets>(),
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
        checkWalletUsecase: locator<CheckWalletStatusUsecase>(),
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
      ),
    );
  }
}
