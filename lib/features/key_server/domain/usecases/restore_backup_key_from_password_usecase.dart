import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// If the key server is up
class RestoreBackupKeyFromPasswordUsecase {
  final RecoverBullRepository recoverBullRepository;

  RestoreBackupKeyFromPasswordUsecase({required this.recoverBullRepository});

  Future<String> execute({
    required String backupFile,
    required String password,
  }) async {
    try {
      if (!EncryptedVault.isValid(backupFile)) {
        throw const KeyServerError.invalidBackupFile();
      }

      final vault = EncryptedVault(file: backupFile);
      final vaultKey = await recoverBullRepository.fetchBackupKey(
        vault.id,
        password,
        vault.salt,
      );

      return vaultKey;
    } on recoverbull.KeyServerException catch (e) {
      throw KeyServerError.fromException(e);
    } catch (e) {
      log.severe('$RestoreBackupKeyFromPasswordUsecase: $e');
      rethrow;
    }
  }
}
