import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CompletePhysicalBackupVerificationUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  Future<void> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final defaultWallets = switch (await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        Ok(:final value) => value,
        // Intentional, not pending work. The local catch below converts this
        // into CompletePhysicalBackupVerificationException, which onboarding's
        // own use-cases then map to OnboardingFailure — the boundary it chose
        // and documented in domain/onboarding_failure.dart, which is rule 11's
        // "feature use-case wrapping a shared core" pattern.
        //
        // Converting this to return a Result would also strand the other
        // consumer, test_wallet_backup, which has no failure family to map
        // into yet.
        Err(:final failure) => throw WalletFailureException(failure),
      };
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }
      // There should only be one default Bitcoin wallet

      for (final defaultWallet in defaultWallets) {
        await _walletRepository.updateBackupInfo(
          walletId: defaultWallet.id,
          isEncryptedVaultTested: defaultWallet.isEncryptedVaultTested,
          isPhysicalBackupTested: true,
          latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
          latestPhysicalBackup: DateTime.now(),
        );
      }
    } catch (e) {
      throw CompletePhysicalBackupVerificationException(e.toString());
    }
  }
}

class CompletePhysicalBackupVerificationException extends BullException {
  CompletePhysicalBackupVerificationException(super.message);
}
