import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:secrets/secrets.dart' as secrets;

/// If the key server is down
class UpdateLatestEncryptedVaultTestUsecase {
  final secrets.Secrets _secrets;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  UpdateLatestEncryptedVaultTestUsecase({
    required this._secrets,
    required this._walletRepository,
    required this._settingsRepository,
  });

  // Orchestrates the still-throwing wallet/settings core repos; the local
  // try/catch is the boundary, mapping any failure to a sanitized core failure.
  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String vaultKey,
  }) async {
    try {
      final inspection = await _secrets.recoverbull.fingerprint(
        vault: secrets.EncryptedVault(json: vault.toFile()),
        key: secrets.VaultKey(vaultKey),
      );
      final String decodedFingerprint;
      switch (inspection) {
        case Ok(:final value):
          decodedFingerprint = value.hex;
        case Err():
          return const Err(
            RecoverBullUnexpectedCoreFailure('Backup verification failed'),
          );
      }

      final settings = await _settingsRepository.fetch();
      final List<Wallet> availableWallets;
      switch (await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        case Ok(:final value):
          availableWallets = value;
        case Err(:final failure):
          log.warning('updateLatestEncryptedVault: ${failure.logMessage}');
          return const Err(
            RecoverBullUnexpectedCoreFailure('Backup restoration failed'),
          );
      }

      for (final wallet in availableWallets) {
        if (wallet.masterFingerprint == decodedFingerprint) {
          await _walletRepository.updateEncryptedBackupTime(
            time: DateTime.now(),
            walletId: wallet.id,
          );
        } else {
          log.warning(
            'The vault mnemonic does not match the current default wallet.',
          );
          await _walletRepository.updateEncryptedBackupTime(
            time: null,
            walletId: wallet.id,
          );
        }
      }
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'updateLatestEncryptedVault failed',
        error: 'Backup restoration failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Backup restoration failed'),
      );
    }
  }
}
