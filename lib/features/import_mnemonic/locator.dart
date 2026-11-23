import 'package:wallet_import/wallet_import.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:secrets/secrets.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:get_it/get_it.dart';

class ImportMnemonicLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CheckDuplicateMnemonicUsecase>(
      () => CheckDuplicateMnemonicUsecase(
        secrets: locator<Secrets>(),
        inventory: locator<SecretsInventory>(),
        settings: locator<Preferences>(),
      ),
    );
    locator.registerFactory<ImportWalletUsecase>(
      () => ImportWalletUsecase(
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
        secrets: locator<Secrets>(),
        settingsRepository: locator<Preferences>(),
        walletRepository: locator<WalletRepository>(),
        admission: locator<ParentCustodyAdmissionPort>(),
      ),
    );
    registerCubit(locator);
  }

  static void registerCubit(GetIt locator) {
    locator.registerFactory<ImportMnemonicCubit>(
      () => ImportMnemonicCubit(
        importWalletUsecase: locator<ImportWalletUsecase>(),
        scanMnemonic: locator<ImportFeature>().scanMnemonic,
        checkDuplicateMnemonicUsecase: locator<CheckDuplicateMnemonicUsecase>(),
      ),
    );
  }
}
