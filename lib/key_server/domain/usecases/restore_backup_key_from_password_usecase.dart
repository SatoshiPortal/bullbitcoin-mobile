import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

/// If the key server is up
class RestoreBackupKeyFromPasswordUsecase {
  final RecoverBullRepository recoverBullRepository;

  RestoreBackupKeyFromPasswordUsecase({
    required this.recoverBullRepository,
  });

  Future<String> execute(String backupFile, String password) async {
    try {
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      final bullBackup = BullBackup.fromJson(backupFile);

      final backupKey = await recoverBullRepository.fetchBackupKey(
        HEX.encode(bullBackup.id),
        password,
        HEX.encode(bullBackup.salt),
      );

      return backupKey;
    } catch (e) {
      debugPrint('$RestoreBackupKeyFromPasswordUsecase: $e');
      rethrow;
    }
  }
}
