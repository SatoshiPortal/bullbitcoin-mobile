import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';

class RecoverWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<RecoverWalletUsecase>(
      () => RecoverWalletUsecase(
        settingsRepository: locator<SettingsRepository>(),
        mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
        walletManager: locator<WalletManagerService>(),
      ),
    );

    // Blocs
    locator.registerFactory<RecoverWalletBloc>(
      () => RecoverWalletBloc(
        findMnemonicWordsUsecase: locator<FindMnemonicWordsUsecase>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );
  }
}
