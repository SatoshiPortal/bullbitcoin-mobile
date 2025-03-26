import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/key_server/data/services/backup_key_service.dart';

import 'package:bb_mobile/key_server/domain/errors/key_server_error.dart'
    show KeyServerError;
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';

import 'package:flutter/foundation.dart';
import 'package:recoverbull/recoverbull.dart';

/// Stores a backup key on the server with password protection
class StoreBackupKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final BackupKeyService _backupKeyService;

  StoreBackupKeyIntoServerUsecase({
    required RecoverBullRepository recoverBullRepository,
    required BackupKeyService backupService,
  })  : _recoverBullRepository = recoverBullRepository,
        _backupKeyService = backupService;

  Future<void> execute({
    required String password,
    required String backupFile,
    required String backupKey,
  }) async {
    try {
      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      final derivedKey = await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: backupInfo.path,
      );

      if (backupKey != derivedKey) {
        throw const KeyServerError.keyMismatch();
      }

      await _recoverBullRepository.storeBackupKey(
        backupInfo.id,
        password,
        backupInfo.salt,
        backupKey,
      );
    } on KeyServerException catch (e) {
      debugPrint('$StoreBackupKeyIntoServerUsecase: $e');
      throw KeyServerError.fromException(e);
    } catch (e) {
      if (e is! KeyServerError) {
        debugPrint('$StoreBackupKeyIntoServerUsecase: $e');
      }
      rethrow;
    }
  }
}
