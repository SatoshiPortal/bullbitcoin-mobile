import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/key_server/domain/validators/password_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class StoreBackupKeyIntoServerUsecase {
  final RecoverBullRepository recoverBullRepository;
  final SeedRepository seedRepository;
  final WalletMetadataRepository walletMetadataRepository;

  StoreBackupKeyIntoServerUsecase({
    required this.recoverBullRepository,
    required this.seedRepository,
    required this.walletMetadataRepository,
  });

  Future<void> execute({
    required String password,
    required String backupFileAsString,
    required String backupKey,
  }) async {
    try {
      // Ensure backupFile has a valid format
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      // Ensure password is not too common
      if (RecoverBullPasswordValidator.isInCommonPasswordList(password)) {
        throw '$StoreBackupKeyIntoServerUsecase: password is too common';
      }

      final derivedBackupKey = await DeriveBackupKeyFromDefaultWalletUsecase(
        recoverBullRepository: recoverBullRepository,
        seedRepository: seedRepository,
        walletMetadataRepository: walletMetadataRepository,
      ).execute(backupFile);

      // Ensure the given backup key is derived from the default wallet
      if (backupKey != derivedBackupKey) {
        throw '$StoreBackupKeyIntoServerUsecase: the given backup key is not derived from the current default wallet';
      }

      final bullBackup = BullBackup.fromJson(backupFile);

      await recoverBullRepository.storeBackupKey(
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
