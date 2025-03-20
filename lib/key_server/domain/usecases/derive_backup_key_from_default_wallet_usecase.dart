import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_utils/bip32_derivation.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:flutter/foundation.dart';
import 'package:recoverbull/recoverbull.dart';

class DeriveBackupKeyFromDefaultWalletUsecase {
  final RecoverBullRepository recoverBullRepository;
  final SeedRepository seedRepository;
  final WalletMetadataRepository walletMetadataRepository;

  DeriveBackupKeyFromDefaultWalletUsecase({
    required this.recoverBullRepository,
    required this.seedRepository,
    required this.walletMetadataRepository,
  });

  Future<String> execute(String backupFile) async {
    try {
      final isValidBackupFile = BullBackup.isValid(backupFile);
      if (!isValidBackupFile) throw 'Invalid backup file';

      // The default wallet is used to derive the backup key
      final defaultMetadata = await walletMetadataRepository.getDefault();
      final defaultFingerprint = defaultMetadata.masterFingerprint;
      final defaultSeed = await seedRepository.get(defaultFingerprint);
      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultMetadata.network,
      );

      final bullBackup = BullBackup.fromJson(backupFile);

      if (bullBackup.path == null) {
        throw '$DeriveBackupKeyFromDefaultWalletUsecase: Bip85 path is missing from the backup file';
      }

      final derivedBackupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, bullBackup.path!);

      return derivedBackupKey;
    } catch (e) {
      debugPrint('$DeriveBackupKeyFromDefaultWalletUsecase: $e');
      rethrow;
    }
  }
}
