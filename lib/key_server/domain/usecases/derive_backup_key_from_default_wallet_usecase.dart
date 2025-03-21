import 'package:bb_mobile/key_server/domain/model/errors/key_server_error.dart';
import 'package:bb_mobile/key_server/domain/services/backup_key_service.dart';
import 'package:flutter/foundation.dart';
import 'package:recoverbull/recoverbull.dart';

class DeriveBackupKeyFromDefaultWalletUsecase {
  final BackupKeyService _backupKeyService;

  DeriveBackupKeyFromDefaultWalletUsecase({
    required BackupKeyService backupKeyService,
  }) : _backupKeyService = backupKeyService;

  Future<String> execute({required String backupFileAsString}) async {
    try {
      if (!BullBackup.isValid(backupFileAsString)) {
        throw const BackupFileInvalidError();
      }
      final bullBackup = BullBackup.fromJson(backupFileAsString);

      return await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: bullBackup.path,
      );
    } catch (e) {
      debugPrint('$DeriveBackupKeyFromDefaultWalletUsecase: $e');
      rethrow;
    }
  }
}
