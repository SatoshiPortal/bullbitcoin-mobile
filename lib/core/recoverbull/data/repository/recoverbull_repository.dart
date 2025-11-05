import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:hex/hex.dart';

class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;

  RecoverBullRepository({required this.remoteDatasource});

  String createJsonVault(String vaultKey, String plaintext) {
    final backupKeyBytes = HEX.decode(vaultKey);
    final plaintextBytes = utf8.encode(plaintext);

    final jsonBackup = RecoverBullDatasource.create(
      plaintextBytes,
      backupKeyBytes,
    );

    return jsonBackup;
  }

  String restoreJsonVault(String vaultFile, String vaultKey) {
    try {
      final decryptedBytes = RecoverBullDatasource.restore(
        vaultFile,
        HEX.decode(vaultKey),
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      log.severe('Error restoring backup: $e');
      rethrow;
    }
  }

  Future<void> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
  ) async {
    await remoteDatasource.store(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      HEX.decode(vaultKey),
    );
  }

  Future<String> fetchVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final vaultKey = await remoteDatasource.fetch(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
    return HEX.encode(vaultKey);
  }

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    await remoteDatasource.trash(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
  }

  Future<void> checkConnection() async {
    await remoteDatasource.checkConnection();
  }
}
