import 'dart:convert';
import 'package:bb_mobile/_core/data/datasources/recoverbull_local_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/recoverbull_remote_data_source.dart';
import 'package:bb_mobile/_core/data/models/seed_model.dart';
import 'package:bb_mobile/_core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';

class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final RecoverBullLocalDataSource localDataSource;
  final RecoverBullRemoteDataSource remoteDataSource;
  RecoverBullRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  String createBackupFile(
    String backupKey,
    String plaintext,
  ) {
    final backupKeyBytes = HEX.decode(backupKey);
    final plaintextBytes = utf8.encode(plaintext);

    final jsonBackup =
        localDataSource.createBackup(plaintextBytes, backupKeyBytes);

    return jsonBackup;
  }

  @override
  Future<List<(Seed, WalletMetadata)>> restoreBackupFile(
    String backupFile,
    String backupKey,
  ) async {
    try {
      // Restore the encrypted backup using the provided key
      final decryptedBytes = localDataSource.restoreBackup(
        backupFile,
        HEX.decode(backupKey),
      );

      // Convert the decrypted bytes to a string
      final plaintext = utf8.decode(decryptedBytes);

      // Parse the JSON array from the plaintext
      final rawBackups = json.decode(plaintext) as List<(String, String)>;
      final List<(Seed, WalletMetadata)> walletBackups = [];

      // Process each backup entry
      for (final backup in rawBackups) {
        final seed =
            SeedModel.fromJson(json.decode(backup.$1) as Map<String, dynamic>)
                .toEntity();
        final wallet = WalletMetadataModel.fromJson(
          json.decode(backup.$2) as Map<String, dynamic>,
        ).toEntity();

        walletBackups.add((seed, wallet));
      }

      return walletBackups;
    } catch (e) {
      debugPrint('Error restoring backup: $e');

      rethrow;
    }
  }

  @override
  Future<void> storeBackupKey(
    String identifier,
    String password,
    String salt,
    String backupKey,
  ) async {
    await remoteDataSource.store(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      HEX.decode(backupKey),
    );
  }

  @override
  Future<String> fetchBackupKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final backupKey = await remoteDataSource.fetch(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
    return HEX.encode(backupKey);
  }

  @override
  Future<void> trashBackupKey(
    String identifier,
    String password,
    String salt,
  ) async {
    await remoteDataSource.trash(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
  }
}
