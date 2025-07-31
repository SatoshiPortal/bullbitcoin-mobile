import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/locator.dart';

class ImportMnemonicLocator {
  static void setup() {
    registerCubit();
    registerUsecases();
  }

  static void registerCubit() {
    locator.registerFactory<ImportMnemonicCubit>(
      () => ImportMnemonicCubit(
        importWalletUsecase: locator<ImportWalletUsecase>(),
        checkWalletUsecase: locator<TheDirtyUsecase>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerLazySingleton<TheDirtyUsecase>(
      () => TheDirtyUsecase(
        locator<SettingsRepository>(),
        locator<ElectrumServerRepository>(),
      ),
    );
  }
}
