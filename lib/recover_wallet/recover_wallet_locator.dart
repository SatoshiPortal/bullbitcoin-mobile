import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';
import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';

class RecoverWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<RecoverWalletUseCase>(
      () => RecoverWalletUseCase(
        settingsRepository: locator<SettingsRepository>(),
        mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
        seedRepository: locator<SeedRepository>(),
        walletManager: locator<WalletManager>(),
      ),
    );

    // Blocs
    locator.registerFactory<RecoverWalletBloc>(
      () => RecoverWalletBloc(
        findMnemonicWordsUseCase: locator<FindMnemonicWordsUseCase>(),
        recoverWalletUseCase: locator<RecoverWalletUseCase>(),
      ),
    );
  }
}
