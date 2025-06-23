import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/recover_or_create_wallet_usecase.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class RecoverWalletLocator {
  static void setup() {
    registerUsecases();
    registerBlocs();
  }

  static void registerUsecases() {
    locator.registerFactory<RecoverOrCreateWalletUsecase>(
      () => RecoverOrCreateWalletUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
  }

  static void registerBlocs() {
    locator.registerFactory<RecoverWalletBloc>(
      () => RecoverWalletBloc(
        findMnemonicWordsUsecase: locator<FindMnemonicWordsUsecase>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );
  }
}
