import 'dart:convert';

import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';

class WalletSensitiveRepository {
  Future<Err?> newSeed({
    required Seed seed,
    required SecureStorage secureStore,
  }) async {
    try {
      final fingerprintIndex = seed.getSeedStorageString();
      final (fingerprintIndexes, err) = await secureStore.getValue(StorageKeys.seeds);
      if (err != null) {
        // no seeds exist make this the first
        final jsn = jsonEncode({
          'seeds': [fingerprintIndex],
        });
        final _ = await secureStore.saveValue(
          key: StorageKeys.seeds,
          value: jsn,
        );
      } else {
        final fingerprintIdsJson = jsonDecode(fingerprintIndexes!)['seeds'] as List<dynamic>;

        final List<String> fingerprints = [];
        for (final fingerprint in fingerprintIdsJson) {
          if (fingerprint == fingerprintIndex)
            return Err('Seed Exists');
          else
            fingerprints.add(fingerprint as String);
        }

        fingerprints.add(fingerprintIndex);

        final jsn = jsonEncode({
          'seeds': [...fingerprints],
        });
        final _ = await secureStore.saveValue(
          key: StorageKeys.seeds,
          value: jsn,
        );
      }

      await secureStore.saveValue(
        key: fingerprintIndex,
        value: jsonEncode(seed),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Err?> newPassphrase({
    required Passphrase passphrase,
    required String seedFingerprintIndex,
    required SecureStorage secureStore,
  }) async {
    try {
      final (seedString, err) = await secureStore.getValue(seedFingerprintIndex);
      if (err != null) {
        // no seeds exist
        return Err('No Seed Exists!');
      }
      final seedJson = jsonDecode(seedString!) as Map<String, dynamic>;
      final seed = Seed.fromJson(seedJson);

      for (final pp in seed.passphrases) {
        if (pp.sourceFingerprint == passphrase.sourceFingerprint) {
          return Err('Passphrase Exists!');
        }
      }
      final updatedPassphrases = List<Passphrase>.from(seed.passphrases)..add(passphrase);
      final updatedSeed = seed.copyWith(passphrases: updatedPassphrases);
      await secureStore.saveValue(
        key: seedFingerprintIndex,
        value: jsonEncode(updatedSeed),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(Seed?, Err?)> readSeed({
    required String fingerprintIndex,
    required SecureStorage secureStore,
  }) async {
    try {
      final (jsn, err) = await secureStore.getValue(fingerprintIndex);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final seed = Seed.fromJson(obj);
      return (seed, null);
    } catch (e) {
      return (
        null,
        Err(e.toString(), expected: e.toString() == 'No Seed with index $fingerprintIndex')
      );
    }
  }

  Future<Err?> updateSeed({
    required Seed seed,
    required SecureStorage secureStore,
  }) async {
    try {
      final (_, err) = await readSeed(
        fingerprintIndex: seed.getSeedStorageString(),
        secureStore: secureStore,
      );
      if (err != null) throw err;
      // improve this error
      // does not exist to update, use create

      final _ = await secureStore.saveValue(
        key: seed.getSeedStorageString(),
        value: jsonEncode(
          seed,
        ),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Err?> deleteSeed({
    required String fingerprint,
    required SecureStorage storage,
  }) async {
    try {
      final (fingerprintIdxs, err) = await storage.getValue(StorageKeys.seeds);
      if (err != null) throw err;

      final fingerprintsJson = jsonDecode(fingerprintIdxs!)['seeds'] as List<dynamic>;

      final List<String> fingerprints = [];
      for (final fingerprint in fingerprintsJson) {
        fingerprints.add(fingerprint as String);
      }

      fingerprints.remove(fingerprint);

      final jsn = jsonEncode({
        'seeds': [...fingerprints],
      });

      final _ = await storage.saveValue(
        key: StorageKeys.seeds,
        value: jsn,
      );

      await storage.deleteValue(fingerprint);

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Err?> deletePassphrase({
    required String passphraseFingerprintIndex,
    required String seedFingerprintIndex,
    required SecureStorage secureStore,
  }) async {
    try {
      final (seedString, err) = await secureStore.getValue(seedFingerprintIndex);
      if (err != null) {
        // no seeds exist
        return Err('No Seed Exists!');
      }
      final seedJson = jsonDecode(seedString!) as Map<String, String>;
      final seed = Seed.fromJson(seedJson);

      final existingPassphrases = seed.passphrases;

      seed.passphrases.clear();

      for (final pp in existingPassphrases) {
        if (pp.sourceFingerprint != passphraseFingerprintIndex) {
          seed.passphrases.add(pp);
        }
      }

      await secureStore.saveValue(
        key: seedFingerprintIndex,
        value: jsonEncode(seed),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
