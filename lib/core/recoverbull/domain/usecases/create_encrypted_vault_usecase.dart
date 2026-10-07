import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:secrets/secrets.dart' as secrets;
import 'package:primitives/primitives.dart' show Fingerprint;

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateEncryptedVaultUsecase {
  final secrets.Secrets _secrets;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CreateEncryptedVaultUsecase({
    required this._secrets,
    required this._walletRepository,
    required this._settingsRepository,
  });

  // Coordinates wallet metadata with the package's sealed backup operation.
  Future<
    Result<({EncryptedVault vault, String vaultKey}), RecoverBullCoreFailure>
  >
  execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final List<Wallet> defaultBitcoinWallets;
      switch (await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        case Ok(:final value):
          defaultBitcoinWallets = value;
        // Deliberately NOT collapsed into the empty-list branch below. This is
        // the backup path: telling a user "no default Bitcoin wallet found"
        // when the wallet store merely failed to read would suggest there is
        // nothing to back up, or that a wallet is gone.
        case Err(:final failure):
          log.warning('create vault: ${failure.logMessage}');
          return Err(
            RecoverBullUnexpectedCoreFailure(
              'Could not read the wallets: ${failure.runtimeType}',
            ),
          );
      }

      if (defaultBitcoinWallets.isEmpty) {
        return const Err(
          RecoverBullUnexpectedCoreFailure('No default Bitcoin wallet found'),
        );
      }

      // The default wallet is used to derive the backup key
      final defaultWallet = defaultBitcoinWallets.first;
      // Creating a vault does not verify a backup. Only successful inspection
      // or restoration records its tested status and date.
      final secret = switch (await _secrets.fetch(
        Fingerprint(defaultWallet.masterFingerprint),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };
      if (!secret.info.isMnemonic) {
        return const Err(
          RecoverBullUnexpectedCoreFailure(
            'Default seed is not a mnemonic seed',
          ),
        );
      }
      // Preserve the historical metadata keys and ISO date encoding. The package adds the mnemonic inside its custody boundary.
      final metadata = <String, dynamic>{
        'masterFingerprint': defaultWallet.masterFingerprint,
        'isEncryptedVaultTested': defaultWallet.isEncryptedVaultTested,
        'isPhysicalBackupTested': defaultWallet.isPhysicalBackupTested,
        'latestEncryptedBackup': defaultWallet.latestEncryptedBackup
            ?.toIso8601String(),
        'latestPhysicalBackup': defaultWallet.latestPhysicalBackup
            ?.toIso8601String(),
      };
      final backup = switch (await secret.backup.recoverbull(
        metadata: metadata,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };
      return Ok((
        vault: EncryptedVault(file: backup.vault.json),
        vaultKey: backup.key.hex,
      ));
    } catch (e, st) {
      log.severe(message: 'createEncryptedVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
