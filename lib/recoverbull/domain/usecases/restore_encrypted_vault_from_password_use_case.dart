import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

/// If the key server is up
class RestoreEncryptedVaultFromPasswordUsecase {
  final RecoverBullRepository recoverBullRepository;
  final WalletManagerService walletManagerService;
  final WalletMetadataRepository walletMetadataRepository;

  RestoreEncryptedVaultFromPasswordUsecase({
    required this.recoverBullRepository,
    required this.walletManagerService,
    required this.walletMetadataRepository,
  });

  Future<void> execute(String backupFile, String password) async {
    try {
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      final bullBackup = BullBackup.fromJson(backupFile);

      final backupKey = await recoverBullRepository.fetchBackupKey(
        HEX.encode(bullBackup.id),
        password,
        HEX.encode(bullBackup.salt),
      );

      await RestoreEncryptedVaultFromBackupKeyUsecase(
        recoverBullRepository: recoverBullRepository,
        walletManagerService: walletManagerService,
        walletMetadataRepository: walletMetadataRepository,
      ).execute(backupFile: backupFile, backupKey: backupKey);
    } catch (e) {
      debugPrint('$RestoreEncryptedVaultFromPasswordUsecase: $e');
      rethrow;
    }
  }
}
