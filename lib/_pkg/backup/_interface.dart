import 'dart:convert';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bip85/bip85.dart' as bip85;
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

abstract class IBackupManager {
  /// Encrypts a list of backups using BIP85 derivation
  Future<((String, String)?, Err?)> encryptBackups({
    required List<Backup> backups,
    required List<String> mnemonic,
    required String network,
  }) async {
    if (backups.isEmpty) {
      return (null, Err('No backups provided'));
    }

    try {
      final now = DateTime.now();
      final (derived, err) = await deriveBackupKey(
        mnemonic,
        network,
        now,
      );
      final plaintext = json.encode(backups.map((i) => i.toJson()).toList());

      if (derived == null) {
        debugPrint(err.toString());
        return (null, Err('Failed to derive backup key'));
      }
      final encrypted = recoverbull.BackupService.createBackup(
        secret: utf8.encode(plaintext),
        backupKey: derived,
        createdAt: now,
      );
      return ((HEX.encode(derived), encrypted), null);
    } catch (e) {
      return (null, Err('Encryption failed: $e'));
    }
  }

  /// Decrypts an encrypted backup using the provided key
  Future<(List<Backup>?, Err?)> decryptBackups({
    required String encrypted,
    required List<int> backupKey,
  }) async {
    try {
      final plaintext = recoverbull.BackupService.restoreBackup(
        backup: encrypted,
        backupKey: backupKey,
      );

      return _parseBackups(plaintext);
    } catch (e) {
      return (null, Err('Decryption failed: $e'));
    }
  }

  Future<(List<int>?, Err?)> deriveBackupKey(
    List<String> mnemonic,
    String network,
    DateTime now,
  ) async {
    try {
      final descriptorSecretKey = await DescriptorSecretKey.create(
        network: BBNetwork.fromString(network).toBdkNetwork(),
        mnemonic: await Mnemonic.fromString(mnemonic.join(' ')),
      );
      // $index must remains within 0 to 2^31−1; ie. 0 to 2147483647
      final index = (now.toUtc().millisecondsSinceEpoch % 2147483647).abs();
      final path = "m/1608'/0'/$index";
      final key = bip85
          .derive(
            xprv: descriptorSecretKey.toString().split('/*').first,
            path: path,
          )
          .sublist(0, 32);
      return (key, null);
    } catch (e) {
      return (null, Err(e.toString()));
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
