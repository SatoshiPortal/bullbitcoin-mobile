// ignore_for_file: file_names

import 'dart:convert';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Migration006 {
  final _sqlite = locator<SqliteDatabase>();
  final logPrefix = '$Migration006:';

  Future<void> seedMnemonicToEntropy() async {
    // Check if this migration already happened by checking if the default seed key exists
    const secureStorageV0_4_4 = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    if (await secureStorageV0_4_4.containsKey(
      key: SeedDatasource.defaultSeedKey,
    )) {
      log.config('$logPrefix already migrated');
      return;
    }

    // Ensure there is a default wallet to migrate
    final wallets =
        await _sqlite.managers.walletMetadatas
            .filter((e) => e.isDefault(true))
            .get();
    if (wallets.isEmpty) {
      log.config('$logPrefix no default wallet found');
      return;
    }

    // Prepare the default seed key
    final defaultWallet = wallets.first;
    final defaultWalletMasterFingerprint = defaultWallet.masterFingerprint;
    final defaultSeedKey = 'seed_$defaultWalletMasterFingerprint';

    // Failed will contains all values that failed to migrate, that will be thrown and displayed to the user in the error screen.
    final failed = <String>[];

    // Get all seed keys to migrate
    final all = await secureStorageV0_4_4.readAll();
    final seedKeys = all.keys.where((key) => key.startsWith('seed_'));
    log.config('$logPrefix migrating ${seedKeys.length} seeds…');
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
        log.fine('$logPrefix $key migrated');
      } catch (e) {
        log.warning('$logPrefix error with $key: $e');
        // Add the failed value to the list
        failed.add(value);
        continue;
      }
    }

    if (failed.isNotEmpty) {
      // If there are failed values, throw an exception.
      // The exception should be catched and display the error screen with the failed values.
      final message = 'Some values have not been migrated, backup them $failed';
      throw Exception(message);
    } else {
      // If everything has been migrated, store the defaultSeedKey to the secure storage.
      // This small improvement will optimize default seed lookup from linear to constant time.
      // Before this improvement we would have to first to filter wallet metadatas to find the default seed master fingerprint.
      // And then lookup for the seed in the secure storage.
      await secureStorageV0_4_4.write(
        key: SeedDatasource.defaultSeedKey,
        value: defaultSeedKey,
      );
      log.fine('$logPrefix default seed $defaultSeedKey set');
      log.fine('$logPrefix accomplished');
    }
  }
}
