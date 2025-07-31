import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';

class RestoreEncryptedVaultFromBackupKeyUsecase {
  final RecoverBullRepository _recoverBull;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  RestoreEncryptedVaultFromBackupKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _recoverBull = recoverBullRepository,
       _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

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
      final settings = await _settingsRepository.fetch();

      final plaintext = _recoverBull.restoreBackupJson(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallet = RecoverBullWallet.fromJson(
        decodedPlaintext,
      );

      // Get all wallets to check for conflicts
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );

      if (defaultWallets.isNotEmpty) {
        if (defaultWallets.any(
          (w) =>
              w.masterFingerprint != decodedRecoverbullWallet.masterFingerprint,
        )) {
          throw const WalletMismatchError();
        }
        throw const DefaultWalletExistsError();
      }

      return decodedRecoverbullWallet;
    } catch (e) {
      log.severe('$RestoreEncryptedVaultFromBackupKeyUsecase: $e');
      rethrow;
    }
  }
}
