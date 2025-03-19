import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/recoverbull/recoverbull_password_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class StoreBackupKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreBackupKeyIntoServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String password,
    required String backupFile,
    required String backupKey,
  }) async {
    try {
      // Ensure backupFile has a valid format
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      // Ensure backupKey is hex encoded
      try {
        HEX.decode(backupKey);
      } catch (e) {
        throw '$StoreBackupKeyIntoServerUsecase: backup key should be hex encoded';
      }

      // Ensure password is not too common
      if (RecoverBullPasswordValidator.isInCommonPasswordList(password)) {
        throw '$StoreBackupKeyIntoServerUsecase: password is too common';
      }

      final bullBackup = BullBackup.fromJson(backupFile);

      await _recoverBullRepository.storeBackupKey(
        HEX.encode(bullBackup.id),
        password,
        HEX.encode(bullBackup.salt),
        backupKey,
      );
    } catch (e) {
      debugPrint('$StoreBackupKeyIntoServerUsecase: $e');
      rethrow;
    }
  }
}
