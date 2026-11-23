import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:get_it/get_it.dart';
import 'package:onboarding/setup.dart';
import 'package:preferences/preferences.dart';

import 'complete_physical_backup_verification_usecase.dart';
import 'domain/usecases/create_onboarding_wallet_usecase.dart';
import 'domain/usecases/recover_onboarding_wallet_usecase.dart';

/// Remove this binding once the wallet owners publish provisioning and
/// physical-backup writes without the legacy wallet catalogue.
({CreateOnboardingWallet create, RecoverOnboardingWallet recover})
bindOnboardingWallets(GetIt services) {
  final defaults = services<DefaultWalletsFacade>();
  return (
    create: CreateOnboardingWalletUsecase(defaultWallets: defaults).execute,
    recover: RecoverOnboardingWalletUsecase(
      defaultWallets: defaults,
      completePhysicalBackupVerificationUsecase:
          CompletePhysicalBackupVerificationUsecase(
            walletRepository: services<WalletRepository>(),
            settingsRepository: services<Preferences>(),
          ),
    ).execute,
  );
}
