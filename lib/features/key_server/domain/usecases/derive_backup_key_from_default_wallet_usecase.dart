import 'package:bb_mobile/features/key_server/data/services/backup_key_service.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:bb_mobile/features/recover_wallet/domain/entities/backup_info.dart';
import 'package:flutter/foundation.dart';

class DeriveBackupKeyFromDefaultWalletUsecase {
  final BackupKeyService _backupKeyService;

  DeriveBackupKeyFromDefaultWalletUsecase({
    required BackupKeyService backupKeyService,
  }) : _backupKeyService = backupKeyService;

  Future<String> execute({required String backupFile}) async {
    try {
      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      return await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: backupInfo.path,
      );
    } catch (e) {
      debugPrint('$DeriveBackupKeyFromDefaultWalletUsecase: $e');
      rethrow;
    }
  }
}
