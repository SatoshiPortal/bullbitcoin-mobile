import 'dart:convert';
import 'dart:math';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_model/wallet_sensitive_data.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bip85/bip85.dart' as bip85;
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

abstract class IRecoverbullManager {
  /// Initialize connection and verify access
  Future<(dynamic, Err?)> connect();

  /// Clean up and disconnect
  Future<void> disconnect();

  /// Encrypts a list of backups using BIP85 derivation
  Future<(({String key, BullBackup backup})?, Err?)> createEncryptedBackup({
    required List<WalletSensitiveData> wallets,
    required List<String> mnemonic,
    required String network,
  }) async {
    if (wallets.isEmpty) return (null, Err('No backups provided'));

    try {
      final plaintext = json.encode(wallets.map((i) => i.toJson()).toList());

      final randomIndex = _deriveRandomIndex();
      final derivationPath = "m/1608'/0'/$randomIndex";

      final (derived, err) =
          await deriveBackupKey(mnemonic, network, derivationPath);
      if (derived == null) {
        debugPrint(err.toString());
        return (null, Err('Failed to derive backup key'));
      }

      final backup = BackupService.createBackup(
        secret: utf8.encode(plaintext),
        backupKey: derived,
      );

      final mapBackup = backup.toMap();
      mapBackup['path'] = derivationPath;

      final backupWithPath = BullBackup.fromMap(mapBackup);

      return ((key: HEX.encode(derived), backup: backupWithPath), null);
    } catch (e) {
      return (null, Err('Encryption failed: $e'));
    }
  }

  /// Decrypts an encrypted backup using the provided key
  Future<(List<WalletSensitiveData>?, Err?)> restoreEncryptedBackup({
    required BullBackup backup,
    required List<int> backupKey,
  }) async {
    try {
      final plaintext = BackupService.restoreBackup(
        backup: backup,
        backupKey: backupKey,
      );

      final decodedJson = jsonDecode(plaintext) as List;
      final backups = decodedJson
          .map(
            (item) =>
                WalletSensitiveData.fromJson(item as Map<String, dynamic>),
          )
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
    String derivationPath,
  ) async {
    try {
      final descriptorSecretKey = await DescriptorSecretKey.create(
        network: BBNetwork.fromString(network).toBdkNetwork(),
        mnemonic: await Mnemonic.fromString(mnemonic.join(' ')),
      );

      final key = bip85
          .derive(
            xprv: descriptorSecretKey.toString().split('/*').first,
            path: derivationPath,
          )
          .sublist(0, 32);
      return (key, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  // Abstract methods to be implemented by concrete classes
  Future<(String?, Err?)> saveEncryptedBackup({
    required BullBackup backup,
    String backupFolder = defaultBackupPath,
  });

  (BullBackup?, Err?) loadEncryptedBackup({required String file}) {
    try {
      final backup = BullBackup.fromJson(file);
      return (backup, null);
    } catch (e) {
      debugPrint('Failed to decode backup: $e');
      return (null, Err('Failed to decode backup'));
    }
  }

  Future<(String?, Err?)> removeEncryptedBackup({required String path});
}
