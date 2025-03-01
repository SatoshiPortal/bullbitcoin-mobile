import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';

class OnboardingLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<CreateDefaultWalletsUseCase>(
      () => CreateDefaultWalletsUseCase(
        settingsRepository: locator<SettingsRepository>(),
        mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
        seedRepository: locator<SeedRepository>(),
        walletManager: locator<WalletManager>(),
      ),
    );

    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUseCase: locator<CreateDefaultWalletsUseCase>(),
      ),
    );
  }
}
