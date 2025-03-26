import 'dart:convert';

import 'package:bb_mobile/_core/data/models/seed_model.dart';
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
      final defaultSeed = await seedRepository.get(defaultFingerprint);
      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final (mnemonic, passphrase) = defaultSeedModel.maybeMap(
        mnemonic: (mnemonic) => (mnemonic.mnemonicWords, mnemonic.passphrase),
        orElse: () =>
            throw 'CreateEncryptedVaultUsecase: Default seed is not a bytes seed',
      );
      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultMetadata.network,
      );

      final defaultWalletMetaData =
          (await walletMetadataRepository.getAll()).firstWhere(
        (metadata) => metadata.masterFingerprint == defaultFingerprint,
        orElse: () =>
            throw 'Default wallet metadata not found for fingerprint: $defaultFingerprint',
      );

      final toBackup = RecoverBullWallet(
        mnemonicPassphrase: (mnemonic, passphrase),
        metadata: defaultWalletMetaData,
      );
      final plaintext = json.encode(toBackup.toJson());
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
