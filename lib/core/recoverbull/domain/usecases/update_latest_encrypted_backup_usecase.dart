import 'dart:typed_data';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';

/// If the key server is down
class UpdateLatestEncryptedVaultTestUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  UpdateLatestEncryptedVaultTestUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  // Orchestrates the still-throwing wallet/settings core repos; the local
  // try/catch is the boundary, mapping any failure to a sanitized core failure.
  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required DecryptedVault decryptedVault,
  }) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final decodedRoot = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed));
      final decodedFingerprint = hex.encode(decodedRoot.fingerprint);

      final settings = await _settingsRepository.fetch();
      final availableWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );

      if (availableWallets.isEmpty ||
          availableWallets.any(
            (wallet) => wallet.masterFingerprint != decodedFingerprint,
          )) {
        return const Err(
          InvalidVaultFileFailure(
            'The vault does not belong to the current wallet.',
          ),
        );
      }

      for (final wallet in availableWallets) {
        await _walletRepository.updateEncryptedBackupTime(
          time: DateTime.now(),
          walletId: wallet.id,
        );
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
