import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/locator.dart';

class ImportMnemonicLocator {
  static void setup() {
    registerCubit();
  }

  static void registerCubit() {
    locator.registerFactory<ImportMnemonicCubit>(
      () => ImportMnemonicCubit(
        importWalletUsecase: locator<ImportWalletUsecase>(),
        checkWalletUsecase: locator<TheDirtyUsecase>(),
      ),
    );
  }
}
