import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class DecryptVaultUsecase {
  final RecoverBullRepository _recoverBull;

  DecryptVaultUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBull = recoverBullRepository;

  DecryptedVault execute({
    required EncryptedVault backupFile,
    required String backupKey,
  }) {
    try {
      final plaintext = _recoverBull.restoreBackupJson(
        backupFile.toFile(),
        backupKey,
      );

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decryptedVault = DecryptedVault.fromJson(decodedPlaintext);
      return decryptedVault;
    } catch (e) {
      log.severe('$DecryptVaultUsecase: $e');
      rethrow;
    }
  }
}
