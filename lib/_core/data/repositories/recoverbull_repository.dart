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
  Future<String> createBackupFile(String masterFingerprint) async {
    final wallets = await walletMetadataDataSource.getAll();
    final List<(String, String)> backups = [];
    for (final wallet in wallets) {
      final seed = await seedDataSource.get(wallet.masterFingerprint);
      backups.add(
        (jsonEncode(seed.toJson()), jsonEncode(wallet.toJson())),
      );
    }
    late SeedModel masterSeed;
    final doesMasterFingerPrintSeedExist =
        await seedDataSource.exists(masterFingerprint);
    if (doesMasterFingerPrintSeedExist) {
      masterSeed = await seedDataSource.get(masterFingerprint);
    } else {
      debugPrint('Master seed not found, trying to fetch first seed for ');
      masterSeed = await seedDataSource.get(
        wallets
            .firstWhere((e) => e.isBitcoin, orElse: () => wallets.first)
            .masterFingerprint,
      );
    }
    final masterSeedEntity = masterSeed.toEntity();
    final masterWallet = wallets.firstWhere(
      (e) => e.masterFingerprint == masterSeedEntity.masterFingerprint,
    );

    final xprv = Bip32Derivation.getXprvFromSeed(
      masterSeedEntity.seedBytes,
      masterWallet.isMainnet ? Network.bitcoinMainnet : Network.bitcoinTestnet,
    );
    final plaintext = json.encode(backups.map((i) => jsonEncode(i)).toList());

    // derive a backup key from a random bip85 path
    final derivationPath = bip85dataSource.generateBackupKeyPath();
    final backupKey =
        bip85dataSource.derive(xprv, derivationPath).sublist(0, 32);

    final jsonBackup =
        localDataSource.createBackup(utf8.encode(plaintext), backupKey);

    // append the path to the backup file
    final mapBackup = json.decode(jsonBackup);
    mapBackup['path'] = derivationPath;

    return json.encode(mapBackup);
  }

  @override
  Future<List<(SeedModel, WalletMetadataModel)>> restoreBackupFile(
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
      final List<(SeedModel, WalletMetadataModel)> walletBackups = [];

      // Process each backup entry
      for (final backup in rawBackups) {
        final seed =
            SeedModel.fromJson(json.decode(backup.$1) as Map<String, dynamic>);
        final wallet = WalletMetadataModel.fromJson(
          json.decode(backup.$2) as Map<String, dynamic>,
        );

        walletBackups.add((seed, wallet));
      }

      return walletBackups;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      throw Exception('Failed to restore backup: $e');
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
