import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class RestoreEncryptedVaultFromPasswordUseCase {
  final RecoverBullRepository _recoverBullRepository;

  RestoreEncryptedVaultFromPasswordUseCase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute(String backupFile, String password) async {
    try {
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      final bullBackup = BullBackup.fromJson(backupFile);

      final backupKey = await _recoverBullRepository.fetchBackupKey(
        HEX.encode(bullBackup.id),
        password,
        HEX.encode(bullBackup.salt),
      );

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
