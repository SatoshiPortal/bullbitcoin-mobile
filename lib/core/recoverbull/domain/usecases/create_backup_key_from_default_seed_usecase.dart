
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip85_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:flutter/foundation.dart';

class CreateBackupKeyFromDefaultSeedUsecase {
  final SeedRepository seedRepository;
  final WalletMetadataRepository walletMetadataRepository;

  CreateBackupKeyFromDefaultSeedUsecase({
    required this.seedRepository,
    required this.walletMetadataRepository,
  });

  Future<String> execute(String derivationPath) async {
    try {
      // The default wallet is used to derive the backup key
      final defaultMetadata = await walletMetadataRepository.getDefault();

      final defaultFingerprint = defaultMetadata.masterFingerprint;
      final defaultSeed = await seedRepository.get(defaultFingerprint);

      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultMetadata.network,
      );

      final backupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, derivationPath);

      return backupKey;
    } catch (e) {
      debugPrint('$CreateBackupKeyFromDefaultSeedUsecase: $e');
      rethrow;
    }
  }
}
