import 'dart:convert';
import 'dart:math';

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
      final randomIndex = _deriveRandomIndex();
      final (derived, err) =
          await deriveBackupKey(mnemonic, network, randomIndex);
      final plaintext = json.encode(backups.map((i) => i.toJson()).toList());

      if (derived == null) {
        debugPrint(err.toString());
        return (null, Err('Failed to derive backup key'));
      }
      final encrypted = recoverbull.BackupService.createBackup(
        secret: utf8.encode(plaintext),
        backupKey: derived,
      );
      final encoded = jsonEncode({
        'index': randomIndex,
        'encrypted': encrypted,
      });
      return ((HEX.encode(derived), encoded), null);
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
      final decodedBackup = jsonDecode(encrypted) as Map<String, dynamic>;
      if (!decodedBackup.containsKey("encrypted")) {
        return (null, Err('Invalid backup format'));
      }

      final plaintext = recoverbull.BackupService.restoreBackup(
        backup: decodedBackup['encrypted'] as String,
        backupKey: backupKey,
      );

      final decodedJson = jsonDecode(plaintext) as List;
      final backups = decodedJson
          .map((item) => Backup.fromJson(item as Map<String, dynamic>))
          .toList();

      return (backups, null);
    } catch (e) {
      return (null, Err('Decryption failed: $e'));
    }
  }

  int _deriveRandomIndex() {
    final random = Uint8List(4);
    final secureRandom = Random.secure();
    for (int i = 0; i < 4; i++) {
      random[i] = secureRandom.nextInt(256);
    }
    final randomIndex =
        ByteData.view(random.buffer).getUint32(0, Endian.little) & 0x7FFFFFFF;

    return randomIndex;
  }

  Future<(List<int>?, Err?)> deriveBackupKey(
    List<String> mnemonic,
    String network,
    int keyPathIndex,
  ) async {
    try {
      final descriptorSecretKey = await DescriptorSecretKey.create(
        network: BBNetwork.fromString(network).toBdkNetwork(),
        mnemonic: await Mnemonic.fromString(mnemonic.join(' ')),
      );

      final key = bip85
          .derive(
            xprv: descriptorSecretKey.toString().split('/*').first,
            path: "m/1608'/0'/$keyPathIndex",
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
