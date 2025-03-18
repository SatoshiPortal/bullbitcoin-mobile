import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:flutter/foundation.dart';

class RestoreEncryptedVaultFromBackupKeyUsecase {
  final RecoverBullRepository _recoverBullRepository;

  RestoreEncryptedVaultFromBackupKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute(String backupFile, String backupKey) async {
    try {
      final jsonBackup = _recoverBullRepository.restoreBackupFile(
        backupFile,
        backupKey,
      );

      // TODO: import wallets
    } catch (e) {
      debugPrint('error creating encrypted backup: $e');
      rethrow;
    }
  }
}
