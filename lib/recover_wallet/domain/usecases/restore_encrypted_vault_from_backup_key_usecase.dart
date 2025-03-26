import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/recoverbull_wallet.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';
import 'package:recoverbull/recoverbull.dart';

/// If the key server is down
class RestoreEncryptedVaultFromBackupKeyUsecase {
  final RecoverBullRepository recoverBullRepository;
  final WalletManagerService walletManagerService;
  final WalletMetadataRepository walletMetadataRepository;

  RestoreEncryptedVaultFromBackupKeyUsecase({
    required this.recoverBullRepository,
    required this.walletManagerService,
    required this.walletMetadataRepository,
  });

  Future<void> execute({
    required String backupFile,
    required String backupKey,
  }) async {
    try {
      // Ensure backupFile has a valid format
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      try {
        await walletMetadataRepository.getDefault();
        throw '$RestoreEncryptedVaultFromBackupKeyUsecase: there is already a default recoverbull cannot succeed';
      } catch (_) {
        // If there is no default wallet `walletMetadataRepository.getDefault()`
        // the function should throw, we do nothing and we continue
      }

      final plaintext =
          recoverBullRepository.restoreBackupFile(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallets =
          RecoverBullWallet.fromJson(decodedPlaintext);

      final seed = Seed.mnemonic(
        mnemonicWords: decodedRecoverbullWallets.mnemonicPassphrase.$1,
        passphrase: decodedRecoverbullWallets.mnemonicPassphrase.$2,
      );
      final metadata = decodedRecoverbullWallets.metadata;
      //TODO: check if this function will cover all the cases

      final liquidNetwork = metadata.network.isMainnet
          ? Network.liquidMainnet
          : Network.liquidTestnet;

      // The default wallets should be 1 Bitcoin and 1 Liquid wallet.
      await Future.wait([
        walletManagerService.createWallet(
          seed: seed,
          network: metadata.network,
          scriptType: metadata.scriptType,
          isDefault: metadata.isDefault,
        ),
        walletManagerService.createWallet(
          seed: seed,
          network: liquidNetwork,
          scriptType: metadata.scriptType,
          isDefault: metadata.isDefault,
        ),
      ]);
      debugPrint('Default wallets created');
    } catch (e) {
      debugPrint('$RestoreEncryptedVaultFromBackupKeyUsecase: $e');
      rethrow;
    }
  }
}
