import 'package:bull_recoverbull/storage.dart';
import 'package:get_it/get_it.dart';
import 'package:onboarding/setup.dart';
import 'package:provisioning/provisioning.dart';

import 'complete_physical_backup_verification_usecase.dart';
import 'domain/usecases/create_onboarding_wallet_usecase.dart';
import 'domain/usecases/recover_onboarding_wallet_usecase.dart';

/// Remove this binding once Onboarding composes default wallet provisioning
/// and physical-backup records itself.
({CreateOnboardingWallet create, RecoverOnboardingWallet recover})
bindOnboardingWallets(GetIt services) {
  final defaults = services<DefaultWalletProvisioning>();
  return (
    create: CreateOnboardingWalletUsecase(defaultWallets: defaults).execute,
    recover: RecoverOnboardingWalletUsecase(
      defaultWallets: defaults,
      completePhysicalBackupVerificationUsecase:
          CompletePhysicalBackupVerificationUsecase(
            backups: services<RecoverBullWalletBackups>(),
            regtestBackups: services<RecoverBullWalletBackups>(
              instanceName: 'regtest',
            ),
          ),
    ).execute,
  );
}
