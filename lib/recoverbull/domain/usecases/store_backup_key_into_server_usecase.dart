import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_utils/bip32_derivation.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:bb_mobile/recoverbull/recoverbull_password_validator.dart';
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
    required String backupFile,
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

      final bullBackup = BullBackup.fromJson(backupFile);

      if (bullBackup.path == null) {
        throw '$StoreBackupKeyIntoServerUsecase: Bip85 path is missing from the backup file';
      }

      // The default wallet is used to derive the backup key
      final defaultMetadata = await walletMetadataRepository.getDefault();
      final defaultFingerprint = defaultMetadata.masterFingerprint;
      final defaultSeed = await seedRepository.get(defaultFingerprint);
      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultMetadata.network,
      );

      // Derive the backup key using BIP85
      final derivedBackupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, bullBackup.path!);

      // Ensure the given backup key is derived from the default wallet
      if (backupKey != derivedBackupKey) {
        throw '$StoreBackupKeyIntoServerUsecase: the given backup key is not derived from the current default wallet';
      }

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
