import 'dart:convert';

import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';

class WalletSensitiveStorageRepository {
  WalletSensitiveStorageRepository({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  Future<Err?> newSeed({
    required Seed seed,
  }) async {
    try {
      final fingerprintIndex = seed.getSeedStorageString();
      final (fingerprintIndexes, err) =
          await _secureStorage.getValue(StorageKeys.seeds);
      if (err != null) {
        // no seeds exist make this the first
        final jsn = jsonEncode({
          'seeds': [fingerprintIndex],
        });
        final _ = await _secureStorage.saveValue(
          key: StorageKeys.seeds,
          value: jsn,
        );
      } else {
        final fingerprintIdsJson =
            jsonDecode(fingerprintIndexes!)['seeds'] as List<dynamic>;

        final List<String> fingerprints = [];
        for (final fingerprint in fingerprintIdsJson) {
          if (fingerprint == fingerprintIndex) {
            return Err('Seed Exists');
          } else {
            fingerprints.add(fingerprint as String);
          }
        }

        fingerprints.add(fingerprintIndex);

        final jsn = jsonEncode({
          'seeds': [...fingerprints],
        });
        final _ = await _secureStorage.saveValue(
          key: StorageKeys.seeds,
          value: jsn,
        );
      }
      // why are we also storing the seed with the index directly? easier to read? backup?
      await _secureStorage.saveValue(
        key: fingerprintIndex,
        value: jsonEncode(seed),
      );
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while saving seed',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> newPassphrase({
    required Passphrase passphrase,
    required String seedFingerprintIndex,
  }) async {
    try {
      final (seedString, err) =
          await _secureStorage.getValue(seedFingerprintIndex);
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
      final updatedPassphrases = List<Passphrase>.from(seed.passphrases)
        ..add(passphrase);
      final updatedSeed = seed.copyWith(passphrases: updatedPassphrases);
      await _secureStorage.saveValue(
        key: seedFingerprintIndex,
        value: jsonEncode(updatedSeed),
      );
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while saving passphrase',
        solution: 'Please try again.',
      );
    }
  }

  Future<(Seed?, Err?)> readSeed({
    required String fingerprintIndex,
  }) async {
    try {
      final (jsn, err) = await _secureStorage.getValue(fingerprintIndex);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final seed = Seed.fromJson(obj);
      return (seed, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          expected: e.toString() == 'No Seed with index $fingerprintIndex',
        )
      );
    }
  }

  // Future<(List<Seed>?, Err?)> readAllSeeds() async {
  //   try {
  //     final (seeds, err) = await _secureStorage.getValue(StorageKeys.seeds);
  //     final fingerprintIdsJson = jsonDecode(seeds!)['seeds'] as List<dynamic>;

  //     if (err != null) throw err;
  //     final obj = jsonDecode(seeds) as Map<String, dynamic>;
  //     final List<Seed> parsedSeeds = [];
  //     for (final fingerprint in fingerprintIdsJson) {
  //       final seed = Seed.fromJson(obj);
  //       parsedSeeds.add(seed);
  //     }
  //     return (parsedSeeds, null);
  //   } catch (e) {
  //     return (null, Err(e.toString()));
  //   }
  // }

  // Future<Err?> updateSeed({
  //   required Seed seed,
  //   required SecureStorage secureStore,
  // }) async {
  //   try {
  //     final (_, err) = await readSeed(
  //       fingerprintIndex: seed.getSeedStorageString(),
  //       secureStore: secureStore,
  //     );
  //     if (err != null) throw err;
  //     // improve this error
  //     // does not exist to update, use create

  //     final _ = await secureStore.saveValue(
  //       key: seed.getSeedStorageString(),
  //       value: jsonEncode(
  //         seed,
  //       ),
  //     );
  //     return null;
  //   } on Exception catch (e) {
  //     return Err(
  //       e.message,
  //       title: 'Error ',
  //       solution: 'Please try again.',
  //     );
  //   }
  // }

  Future<Err?> deleteSeed({
    required String fingerprint,
  }) async {
    try {
      final (fingerprintIdxs, err) =
          await _secureStorage.getValue(StorageKeys.seeds);
      if (err != null) throw err;

      final fingerprintsJson =
          jsonDecode(fingerprintIdxs!)['seeds'] as List<dynamic>;

      final List<String> fingerprints = [];
      for (final fingerprint in fingerprintsJson) {
        fingerprints.add(fingerprint as String);
      }

      fingerprints.remove(fingerprint);

      final jsn = jsonEncode({
        'seeds': [...fingerprints],
      });

      final _ = await _secureStorage.saveValue(
        key: StorageKeys.seeds,
        value: jsn,
      );

      await _secureStorage.deleteValue(fingerprint);

      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while deleting seed',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> deletePassphrase({
    required String passphraseFingerprintIndex,
    required String seedFingerprintIndex,
  }) async {
    try {
      final (seedString, err) =
          await _secureStorage.getValue(seedFingerprintIndex);
      if (err != null) {
        // no seeds exist
        return Err('No Seed Exists!');
      }
      final seedJson = jsonDecode(seedString!);
      var seed = Seed.fromJson(seedJson as Map<String, dynamic>);

      final existingPassphrases = seed.passphrases.toList();

      final List<Passphrase> passphrases = [];
      for (final pp in existingPassphrases) {
        if (pp.sourceFingerprint != passphraseFingerprintIndex) {
          passphrases.add(pp);
        }
      }

      seed = seed.copyWith(passphrases: passphrases);

      await _secureStorage.saveValue(
        key: seedFingerprintIndex,
        value: jsonEncode(seed),
      );
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while deleting passphrase',
        solution: 'Please try again.',
      );
    }
  }
}
