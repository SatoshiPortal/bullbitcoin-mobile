import 'dart:convert';
import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bip85/bip85.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

abstract class IBackupManager {
  /// Encrypts a list of backups using BIP85 derivation
  Future<((String, String)?, Err?)> encryptBackups({
    required List<Backup> backups,
    required String derivationPath,
  }) async {
    if (backups.isEmpty) {
      return (null, Err('No backups provided'));
    }

    try {
      final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
      final key = await _deriveBackupKey(
        mnemonic: backups.first.mnemonic.join(' '),
        network: backups.first.network,
        path: derivationPath,
      );

      if (key == null) {
        return (null, Err('Failed to derive backup key'));
      }
      final encrypted = recoverbull.BackupService.createBackup(
        secret: utf8.encode(plaintext),
        backupKey: key,
      );
      return ((HEX.encode(key), encrypted), null);
    } catch (e) {
      return (null, Err('Encryption failed: $e'));
    }
  }

  /// Decrypts an encrypted backup using the provided key
  Future<(List<Backup>?, Err?)> decryptBackups({
    required String encrypted,
    required String backupKey,
  }) async {
    try {
      final key = HEX.decode(backupKey);
      final plaintext = recoverbull.BackupService.restoreBackup(
        backup: encrypted,
        backupKey: key,
      );

      return _parseBackups(plaintext);
    } catch (e) {
      return (null, Err('Decryption failed: $e'));
    }
  }

  Future<List<int>?> _deriveBackupKey({
    required String mnemonic,
    required String network,
    required String path,
  }) async {
    try {
      final mne = await Mnemonic.fromString(mnemonic);
      final descriptorSecretKey = await DescriptorSecretKey.create(
        network: BBNetwork.fromString(network).toBdkNetwork(),
        mnemonic: mne,
      );
      final res = derive(
        xprv: descriptorSecretKey.toString().split('/*').first,
        path: path,
      );
      return res.sublist(0, 32);
    } catch (e) {
      return null;
    }
  }

  (List<Backup>?, Err?) _parseBackups(String plaintext) {
    try {
      final decodedJson = jsonDecode(plaintext) as List;
      final backups = decodedJson
          .map((item) => Backup.fromJson(item as Map<String, dynamic>))
          .toList();
      return (backups, null);
    } catch (e) {
      return (null, Err('Failed to parse backups: $e'));
    }
  }

  // Abstract methods to be implemented by concrete classes
  Future<(String?, Err?)> saveEncryptedBackup({
    required String encrypted,
    String backupFolder = defaultBackupPath,
  });

  Future<(Map<String, dynamic>?, Err?)> loadEncryptedBackup({
    required String encrypted,
  });

  Future<(String?, Err?)> removeEncryptedBackup({
    required String backupName,
    String backupFolder = defaultBackupPath,
  });
}
