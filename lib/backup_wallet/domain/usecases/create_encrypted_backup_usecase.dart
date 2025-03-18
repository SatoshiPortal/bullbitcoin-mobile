import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/recoverbull_wallet.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_utils/bip32_derivation.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:flutter/foundation.dart';

class CreateEncryptedBackupUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final SeedRepository _seedRepository;
  final WalletMetadataRepository _walletMetadataRepository;
  CreateEncryptedBackupUsecase({
    required RecoverBullRepository recoverBullRepository,
    required SeedRepository seedRepository,
    required WalletMetadataRepository walletMetadataRepository,
  })  : _recoverBullRepository = recoverBullRepository,
        _seedRepository = seedRepository,
        _walletMetadataRepository = walletMetadataRepository;

  Future<String> execute() async {
    try {
      final defaultMetadata = await _walletMetadataRepository.getDefault();
      final defaultFingerprint = defaultMetadata.masterFingerprint;
      final defaultSeed = await _seedRepository.get(defaultFingerprint);

      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultMetadata.network,
      );

      final derivationPath = Bip85Derivation.generateBackupKeyPath();
      final backupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, derivationPath);

      final walletsMetadata = await _walletMetadataRepository.getAll();
      final List<RecoverBullWallet> toBackup = [];

      for (final metadata in walletsMetadata) {
        final seed = await _seedRepository.get(metadata.masterFingerprint);
        toBackup.add(
          RecoverBullWallet(seed: seed.bytes, metadata: metadata),
        );
      }

      final plaintext = json.encode(toBackup.map((e) => e.toJson()).toList());

      final encryptedBackup = _recoverBullRepository.createBackupFile(
        backupKey,
        plaintext,
      );

      // Append the path to the backup file
      final mapBackup = json.decode(encryptedBackup);
      mapBackup['path'] = derivationPath;

      return json.encode(mapBackup);
    } catch (e) {
      debugPrint('error creating encrypted backup: $e');
      rethrow;
    }
  }
}
