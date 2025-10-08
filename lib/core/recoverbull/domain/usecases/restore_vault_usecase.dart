import 'dart:typed_data';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';

/// If the key server is down
class RestoreVaultUsecase {
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreVaultUsecase({
    required WalletRepository walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  }) : _walletRepository = walletRepository,
       _createDefaultWallets = createDefaultWalletsUsecase;

  Future<void> execute({required DecryptedVault decryptedVault}) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final decodedRoot = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed));
      final decodedFingerprint = hex.encode(decodedRoot.fingerprint);

      final availableWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );

      // This is for test flows, since onboarding should have no wallets
      for (final wallet in availableWallets) {
        if (wallet.masterFingerprint == decodedFingerprint) {
          await _walletRepository.updateEncryptedBackupTime(
            DateTime.now(),
            walletId: wallet.id,
          );

          // These are only cases for test flows.
          throw TestFlowDefaultWalletAlreadyExistsError();
        } else {
          throw TestFlowWalletMismatchError();
        }
      }

      final restoredWallets = await _createDefaultWallets.execute(
        mnemonicWords: mnemonic.words,
      );

      log.fine('Default wallets created');

      for (final wallet in restoredWallets) {
        await _walletRepository.updateBackupInfo(
          isEncryptedVaultTested: true,
          isPhysicalBackupTested: decryptedVault.isPhysicalBackupTested,
          latestEncryptedBackup: DateTime.now(),
          latestPhysicalBackup: decryptedVault.latestPhysicalBackup,
          walletId: wallet.id,
        );
      }

      log.info('Default wallets updated');
    } catch (e) {
      log.severe('$RestoreVaultUsecase: $e');
      rethrow;
    }
  }
}
