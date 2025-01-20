import 'dart:convert';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

abstract class IBackupManager {
  /// Encrypts a list of backups using BIP85.
  /// Returns a tuple containing the backupKey and encrypted data or an error.
  Future<((String, String)?, Err?)> encryptBackups({
    required List<Backup> backups,
    required String derivationPath,
    required String backupKeyMnemonic,
  }) async {
    try {
      final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
      final (backupKey, encrypted) = await BackupService.createBackupWithBIP85(
        plaintext: plaintext,
        mnemonic: backupKeyMnemonic,
        network: backups.first.network.toLowerCase(),
        derivationPath: derivationPath,
      );
      return ((backupKey, encrypted), null);
    } catch (e) {
      return (null, Err('Failed to encrypt backups: $e'));
    }
  }

  /// Decrypts an encrypted backup using the provided backup key.
  /// Returns a list of backups.
  Future<(List<Backup>?, Err?)> decryptBackups({
    required String encrypted,
    required String backupKey,
  }) async {
    try {
      final plaintext = await BackupService.restoreBackup(encrypted, backupKey);
      final decodedJson = jsonDecode(plaintext) as List;
      final backups = decodedJson
          .map((item) => Backup.fromJson(item as Map<String, dynamic>))
          .toList();
      return (backups, null);
    } catch (e) {
      return (null, Err('Failed to decrypt backups: $e'));
    }
  }

  /// Writes the encrypted backup to a storage medium.
  /// Returns the path to the written backup or an error.
  Future<(String?, Err?)> saveEncryptedBackup({
    required String encrypted,
    String backupFolder = defaultBackupPath,
  });

  /// Reads the encrypted backup from a storage medium.
  /// Returns a map containing the backup data and the backup ID, or an error.
  Future<(Map<String, dynamic>?, Err?)> loadEncryptedBackup({
    required String encrypted,
  });

  /// Deletes the encrypted backup from a storage medium.
  /// Returns the path to the deleted backup or an error.
  Future<(String?, Err?)> removeEncryptedBackup({
    required String backupName,
    String backupFolder = defaultBackupPath,
  });
}
