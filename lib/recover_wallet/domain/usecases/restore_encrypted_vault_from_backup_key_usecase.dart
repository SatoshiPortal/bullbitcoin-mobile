import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/recoverbull_wallet.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/key_server/domain/errors/key_server_error.dart';
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:flutter/foundation.dart';

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
      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      final availableWallets = await walletMetadataRepository.getAll();
      for (final wallet in availableWallets) {
        if (wallet.isDefault) {
          throw 'there is already a default recoverbull cannot succeed';
        }
      }
      final plaintext =
          recoverBullRepository.restoreBackupFile(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallets =
          RecoverBullWallet.fromJson(decodedPlaintext);

      final seed = Seed.mnemonic(
        mnemonicWords: decodedRecoverbullWallets.mnemonic,
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
