import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/key_server/data/services/backup_key_service.dart';

import 'package:bb_mobile/key_server/domain/errors/key_server_error.dart'
    show KeyServerError;

import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
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
    required String backupFileAsString,
    required String backupKey,
  }) async {
    try {
      if (!BullBackup.isValid(backupFileAsString)) {
        throw const KeyServerError.invalidBackupFile();
      }

      final bullBackup = BullBackup.fromJson(backupFileAsString);
      final derivedKey = await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: bullBackup.path,
      );

      if (backupKey != derivedKey) {
        throw const KeyServerError.keyMismatch();
      }

      await _recoverBullRepository.storeBackupKey(
        HEX.encode(bullBackup.id),
        password,
        HEX.encode(bullBackup.salt),
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
