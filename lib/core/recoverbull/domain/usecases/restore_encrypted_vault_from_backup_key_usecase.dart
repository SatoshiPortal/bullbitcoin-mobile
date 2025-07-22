import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';

class RestoreEncryptedVaultFromBackupKeyUsecase {
  final RecoverBullRepository _recoverBull;
  final WalletRepository _walletRepository;

  RestoreEncryptedVaultFromBackupKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
    required WalletRepository walletRepository,
  }) : _recoverBull = recoverBullRepository,
       _walletRepository = walletRepository;

  Future<RecoverBullWallet> execute({
    required String backupFile,
    required String backupKey,
    bool isVerifying = false,
  }) async {
    try {
      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      final plaintext = _recoverBull.restoreBackupJson(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallet = RecoverBullWallet.fromJson(
        decodedPlaintext,
      );

      // Get all wallets to check for conflicts
      final allWallets = await _walletRepository.getWallets(
        onlyDefaults: false,
        environment: Environment.mainnet,
      );
      // Check if any default wallet exists (different fingerprint)
      final defaultWallets = allWallets.where((w) => w.isDefault).toList();
      if (defaultWallets.isNotEmpty) {
        if (isVerifying &&
            !defaultWallets.every(
              (w) =>
                  w.masterFingerprint ==
                  decodedRecoverbullWallet.masterFingerprint,
            )) {
          throw const WalletMismatchError();
        }
        throw DefaultWalletExistsError(decodedRecoverbullWallet);
      }
      // Check for duplicate wallet (default or non-default)
      final duplicateWallet = allWallets.any(
        (w) =>
            w.masterFingerprint == decodedRecoverbullWallet.masterFingerprint,
      );

      if (duplicateWallet) {
        throw const WalletAlreadyExistsError();
      }

      // No default wallet exists and no duplicate - return for default wallet creation
      return decodedRecoverbullWallet;
    } catch (e) {
      log.severe('$RestoreEncryptedVaultFromBackupKeyUsecase: $e');
      rethrow;
    }
  }
}
