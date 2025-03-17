import 'dart:convert';

import 'package:bb_mobile/_core/data/models/seed_model.dart';
import 'package:bb_mobile/_core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
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
        defaultSeed.seedBytes,
        defaultMetadata.network,
      );

      final derivationPath = Bip85Derivation.generateBackupKeyPath();
      final backupKey =
          Bip85Derivation.deriveBackupKey(defaultXprv, derivationPath);

      final walletsMetadata = await _walletMetadataRepository.getAll();

      // Collect all wallet and seed pairs
      final List<({SeedModel seed, WalletMetadataModel metadata})> toBackup =
          [];
      for (final walletMetadata in walletsMetadata) {
        final seed =
            await _seedRepository.get(walletMetadata.masterFingerprint);
        final seedModel = SeedModel.fromEntity(seed);
        final metadataModel = WalletMetadataModel.fromEntity(walletMetadata);
        toBackup.add((seed: seedModel, metadata: metadataModel));
      }

      // Ensure we have at least one successful backup
      if (toBackup.isEmpty) throw "Failed to create any wallet backups";

      final List<Map<String, dynamic>> toBackupMap = toBackup
          .map(
            (entry) => {
              'seed': entry.seed.toJson(),
              'metadata': entry.metadata.toJson(),
            },
          )
          .toList();

      final plaintext = json.encode(toBackupMap);

      // final plaintext = json.encode(backups.map((i) => jsonEncode(i)).toList());

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
