import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
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

      final plaintext =
          recoverBullRepository.restoreBackupFile(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallets =
          RecoverBullWallet.fromJson(decodedPlaintext);

      final seed = Seed.mnemonic(
        mnemonicWords: decodedRecoverbullWallets.mnemonic,
      );
      final metadata = decodedRecoverbullWallets.metadata;
      final availableWallets = await walletMetadataRepository.getAll();
      for (final wallet in availableWallets) {
        if (wallet.isDefault && wallet.network == Network.bitcoinMainnet) {
          if (wallet.masterFingerprint == metadata.masterFingerprint) {
            walletMetadataRepository.store(
              wallet.copyWith(
                lastestEncryptedBackup: DateTime.now(),
              ),
            );
            throw const DefaultWalletAlreadyExistsError();
          } else {
            throw const WalletMismatchError();
          }
        }
      }
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
          label: metadata.label,
        ),
        walletManagerService.createWallet(
          seed: seed,
          network: liquidNetwork,
          scriptType: metadata.scriptType,
          isDefault: metadata.isDefault,
          label: metadata.label,
        ),
      ]);
      debugPrint('Default wallets created');
      final recoveredWallet = await walletMetadataRepository.getDefault();
      walletMetadataRepository.store(
        recoveredWallet.copyWith(
          isEncryptedVaultTested: true,
          isPhysicalBackupTested: metadata.isPhysicalBackupTested,
          lastestEncryptedBackup: metadata.lastestEncryptedBackup,
          lastestPhysicalBackup: metadata.lastestPhysicalBackup,
        ),
      );
      debugPrint('Default wallet updated');
    } catch (e) {
      debugPrint('$RestoreEncryptedVaultFromBackupKeyUsecase: $e');
      rethrow;
    }
  }
}
