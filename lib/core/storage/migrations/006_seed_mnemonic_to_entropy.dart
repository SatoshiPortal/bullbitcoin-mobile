// ignore_for_file: file_names

import 'dart:convert';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Migration006 {
  final _sqlite = locator<SqliteDatabase>();

  Future<void> seedMnemonicToEntropy() async {
    // Check if this migration already happened by checking if the default seed key exists
    const secureStorageV0_4_4 = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    // Get all seed keys to migrate
    final all = await secureStorageV0_4_4.readAll();
    final seedKeys = all.keys.where((key) => key.startsWith('seed_'));
    if (seedKeys.isEmpty) {
      log.config('$Migration006: no seed keys found to migrate');
      return;
    }

    // Ensure there is a default wallet to migrate
    final wallets =
        await _sqlite.managers.walletMetadatas
            .filter((e) => e.isDefault(true))
            .get();

    if (wallets.isEmpty) {
      log.config('$Migration006: no default wallet found to migrate');
      return;
    }

    // Failed will contains all values that failed to migrate, that will be thrown and displayed to the user in the error screen.
    final failed = <String>[];
    log.config('$Migration006: migrating ${seedKeys.length} seeds…');
    for (final key in seedKeys) {
      final value = await secureStorageV0_4_4.read(key: key);
      if (value == null) continue;

      try {
        // Decode v0.4.4 seed stored as english `mnemonicWords` and `passphrase`
        final json = jsonDecode(value);
        final words = json['mnemonicWords'] as List<dynamic>?;
        final passphrase = json['passphrase'] as String?;
        final mnemonic = Mnemonic.fromWords(
          words: words?.cast<String>() ?? [],
          passphrase: passphrase ?? '',
        );

        // New seed format is based on `hexEntropy` and `passphrase`
        // Which reduce secure storage size
        final newSeedModel = jsonEncode({
          'hexEntropy': hex.encode(mnemonic.entropy),
          'passphrase': mnemonic.passphrase,
        });

        await secureStorageV0_4_4.write(key: key, value: newSeedModel);
        log.fine('$Migration006: $key migrated');
      } catch (e) {
        log.warning('$Migration006: error with $key: $e');
        // Add the failed value to the list
        failed.add(value);
        continue;
      }
    }

    // If there are failed values, throw an exception.
    // The exception should be catched and display the error screen with the failed values.
    if (failed.isNotEmpty) throw Migration006Error(failed);

    log.fine('$Migration006: accomplished');
  }
}

class Migration006Error implements Exception {
  final List<String> failed;

  Migration006Error(this.failed);

  @override
  String toString() =>
      'Some values have not been migrated, backup them $failed';
}
