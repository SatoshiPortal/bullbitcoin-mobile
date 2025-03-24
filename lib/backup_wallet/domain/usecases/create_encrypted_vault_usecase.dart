import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/recoverbull_wallet.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_utils/bip32_derivation.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:flutter/foundation.dart';

class CreateEncryptedVaultUsecase {
  final RecoverBullRepository recoverBullRepository;
  final SeedRepository seedRepository;
  final WalletMetadataRepository walletMetadataRepository;

  CreateEncryptedVaultUsecase({
    required this.recoverBullRepository,
    required this.seedRepository,
    required this.walletMetadataRepository,
  });

  Future<String> execute() async {
    try {
      // The default wallet is used to derive the backup key
      final defaultMetadata = await walletMetadataRepository.getDefault();

      final defaultFingerprint = defaultMetadata.masterFingerprint;
      final defaultSeedExists = await seedRepository.exists(defaultFingerprint);
      if (!defaultSeedExists) {
        throw 'CreateEncryptedVaultUsecase: Default seed not found for fingerprint: $defaultFingerprint';
      }
      final defaultSeed = await seedRepository.get(defaultFingerprint);

      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultMetadata.network,
      );
      // Prepare the plaintext that will be encrypted in the backup
      final walletsMetadata = await walletMetadataRepository.getAll();
      final List<RecoverBullWallet> toBackup = [];
      for (final metadata in walletsMetadata) {
        final seed = await seedRepository.get(metadata.masterFingerprint);

        toBackup.add(
          RecoverBullWallet(seed: seed.bytes, metadata: metadata),
        );
      }
      final plaintext = json.encode(toBackup.map((e) => e.toJson()).toList());

      // Derive the backup key using BIP85
      final derivationPath = Bip85Derivation.generateBackupKeyPath();

      final backupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, derivationPath);

      // Create an encrypted backup file
      final encryptedBackup = recoverBullRepository.createBackupFile(
        backupKey,
        plaintext,
      );

      // Add the BIP85 derivation path (backup key) to the backup file
      final mapBackup = json.decode(encryptedBackup);
      mapBackup['path'] = derivationPath;

      return json.encode(mapBackup);
    } catch (e) {
      debugPrint('$CreateEncryptedVaultUsecase: $e');
      rethrow;
    }
  }
}
