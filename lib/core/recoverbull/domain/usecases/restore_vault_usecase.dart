import 'dart:typed_data';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// If the key server is down
class RestoreVaultUsecase {
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;
  final SettingsRepository _settingsRepository;

  RestoreVaultUsecase({
    required this._walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required this._settingsRepository,
  }) : _createDefaultWallets = createDefaultWalletsUsecase;

  // Orchestrates the still-throwing wallet core repo; the local try/catch is
  // the boundary, mapping any failure to a sanitized core failure.
  Future<Result<List<WalletPreferences>, RecoverBullCoreFailure>> execute({
    required DecryptedVault decryptedVault,
  }) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      // Default-wallet creation reuses existing defaults. Verify their full
      // account keys first so an unrelated backup cannot appear restored or
      // mark those wallets as backed up. No existing wallet is required on a
      // fresh installation.
      final settings = await _settingsRepository.fetch();
      final existing = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );
      final seedBytes = Uint8List.fromList(mnemonic.seed);
      for (final wallet in existing) {
        final key = wallet.singleDescriptorKey;
        if (key == null ||
            key.derivationPath == null ||
            !Bip32Derivation.seedMatchesXpub(
              seedBytes: seedBytes,
              derivationPath: key.derivationPath!,
              xpub: key.xpub,
            )) {
          return const Err(
            InvalidVaultFileFailure('Backup does not match existing wallets'),
          );
        }
      }

      final restoredWallets = await _createDefaultWallets.execute(
        mnemonicWords: mnemonic.words,
      );

      for (final wallet in restoredWallets.wallets) {
        await _walletRepository.updateEncryptedBackupTime(
          time: DateTime.now(),
          walletId: wallet.id,
        );
      }

      log.fine('Vault restored');
      return Ok(restoredWallets.createdWalletPreferences);
    } catch (e, st) {
      log.severe(
        message: 'restoreVault failed',
        error: 'Vault restoration failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault restoration failed'),
      );
    }
  }
}
