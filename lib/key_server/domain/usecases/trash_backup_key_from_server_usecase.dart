import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

/// Removes a backup key from the server using the provided password and backup file
class TrashBackupKeyFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  TrashBackupKeyFromServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String password,
    required String backupFile,
  }) async {
    try {
      if (!BullBackup.isValid(backupFile)) {
        throw 'Corrupted backup file';
      }

      final bullBackup = BullBackup.fromJson(backupFile);

      return _recoverBullRepository.trashBackupKey(
        HEX.encode(bullBackup.id),
        password,
        HEX.encode(bullBackup.salt),
      );
    } catch (e) {
      debugPrint('$TrashBackupKeyFromServerUsecase: $e');
      rethrow;
    }
  }
}
