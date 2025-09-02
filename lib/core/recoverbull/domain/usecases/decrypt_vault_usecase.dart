import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class DecryptVaultUsecase {
  final RecoverBullRepository _recoverBull;

  DecryptVaultUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBull = recoverBullRepository;

  RecoverBullWallet execute({
    required EncryptedVault backupFile,
    required String backupKey,
  }) {
    try {
      final plaintext = _recoverBull.restoreBackupJson(
        backupFile.toFile(),
        backupKey,
      );

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decryptedVault = RecoverBullWallet.fromJson(decodedPlaintext);
      return decryptedVault;
    } catch (e) {
      log.severe('$DecryptVaultUsecase: $e');
      rethrow;
    }
  }
}
