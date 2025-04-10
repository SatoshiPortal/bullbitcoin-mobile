import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:flutter/foundation.dart';

/// If the key server is down
class RestoreEncryptedVaultFromBackupKeyUsecase {
  final RecoverBullRepository _recoverBull;
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreEncryptedVaultFromBackupKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
    required WalletRepository walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  })  : _recoverBull = recoverBullRepository,
        _walletRepository = walletRepository,
        _createDefaultWallets = createDefaultWalletsUsecase;

  Future<void> execute({
    required String backupFile,
    required String backupKey,
  }) async {
    try {
      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      final plaintext = _recoverBull.restoreBackupFile(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallets =
          RecoverBullWallet.fromJson(decodedPlaintext);

      final availableWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );
      for (final defaultWallet in availableWallets) {
        if (defaultWallet.masterFingerprint ==
            decodedRecoverbullWallets.masterFingerprint) {
          await _walletRepository.updateEncryptedBackupTime(
            DateTime.now(),
            walletId: defaultWallet.id,
          );
          throw const DefaultWalletAlreadyExistsError();
        } else {
          throw const WalletMismatchError();
        }
      }

      final restoredWallets = await _createDefaultWallets.execute(
        mnemonicWords: decodedRecoverbullWallets.mnemonic,
      );
      debugPrint('Default wallets created');
      for (final wallet in restoredWallets) {
        await _walletRepository.updateBackupInfo(
          isEncryptedVaultTested: true,
          isPhysicalBackupTested:
              decodedRecoverbullWallets.isPhysicalBackupTested,
          latestEncryptedBackup: DateTime.now(),
          latestPhysicalBackup: decodedRecoverbullWallets.latestPhysicalBackup,
          walletId: wallet.id,
        );
      }

      debugPrint('Default wallets updated');
    } catch (e) {
      debugPrint('$RestoreEncryptedVaultFromBackupKeyUsecase: $e');
      rethrow;
    }
  }
}
