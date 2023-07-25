import 'dart:convert';

import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';

class WalletRepository {
  Future<Err?> createWallet({
    required Wallet wallet,
    required HiveStorage hiveStore,
  }) async {
    try {
      final walletIdIndex = wallet.getStorageString();
      final (walletIds, err) = await hiveStore.getValue(StorageKeys.wallets);
      if (err != null) {
        // no wallets exist make this the first
        final jsn = jsonEncode({
          'wallets': [walletIdIndex]
        });
        final _ = await hiveStore.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      } else {
        final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

        final List<String> walletHashIds = [];
        for (final id in walletIdsJson) {
          if (id == walletIdIndex)
            return Err('Wallet Exists');
          else
            walletHashIds.add(id as String);
        }

        walletHashIds.add(walletIdIndex);

        final jsn = jsonEncode({
          'wallets': [...walletHashIds]
        });
        final _ = await hiveStore.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      }

      await hiveStore.saveValue(
        key: walletIdIndex,
        value: jsonEncode(wallet),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Err?> createSeed({
    required Seed seed,
    required SecureStorage secureStore,
  }) async {
    try {
      final fingerprintIndex = seed.getSeedStorageString();
      final (fingerprintIndexes, err) = await secureStore.getValue(StorageKeys.seeds);
      if (err != null) {
        // no seeds exist make this the first
        final jsn = jsonEncode({
          'seeds': [fingerprintIndex]
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
          'seeds': [...fingerprints]
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

  Future<Err?> createPassphrase({
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
      final seedJson = jsonDecode(seedString!) as Map<String, String>;
      final seed = Seed.fromJson(seedJson);

      for (final pp in seed.passphrases) {
        if (pp.sourceFingerprint == passphrase.sourceFingerprint) {
          return Err('Passphrase Exists!');
        }
      }

      seed.passphrases.add(passphrase);

      await secureStore.saveValue(
        key: seedFingerprintIndex,
        value: jsonEncode(seed),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(Wallet?, Err?)> readWallet({
    required String walletHashId,
    required HiveStorage hiveStore,
  }) async {
    try {
      final (jsn, err) = await hiveStore.getValue(walletHashId);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final wallet = Wallet.fromJson(obj);
      return (wallet, null);
    } catch (e) {
      return (
        null,
        Err(e.toString(), expected: e.toString() == 'No Wallet with index $walletHashId')
      );
    }
  }

  Future<(List<Wallet>?, Err?)> readAllWallets({
    required HiveStorage hiveStore,
  }) async {
    try {
      final (walletIds, err) =
          await hiveStore.getValue(StorageKeys.wallets); // returns wallet indexes
      if (err != null) throw err;

      final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

      final List<Wallet> wallets = [];
      for (final w in walletIdsJson) {
        try {
          final (wallet, err) = await readWallet(
            walletHashId: w as String,
            hiveStore: hiveStore,
          );
          if (err != null) continue;
          wallets.add(wallet!);
        } catch (e) {
          print(e);
        }
      }

      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No Key'));
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

  Future<Err?> updateWallet({
    required Wallet wallet,
    required HiveStorage hiveStore,
  }) async {
    try {
      final (_, err) = await readWallet(
        walletHashId: wallet.getStorageString(),
        hiveStore: hiveStore,
      );
      if (err != null) throw err;
      // improve this error
      // does not exist to update, use create

      final _ = await hiveStore.saveValue(
        key: wallet.getStorageString(),
        value: jsonEncode(
          wallet,
        ),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
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

  Future<Err?> deleteWallet({
    required String walletHashId,
    required HiveStorage hiveStore,
  }) async {
    try {
      final (walletIds, err) = await hiveStore.getValue(StorageKeys.wallets);
      if (err != null) throw err;

      final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

      final List<String> walletHashIds = [];
      for (final id in walletIdsJson) {
        walletHashIds.add(id as String);
      }

      walletHashIds.remove(walletHashId);

      final jsn = jsonEncode({
        'wallets': [...walletHashIds]
      });

      final _ = await hiveStore.saveValue(
        key: StorageKeys.wallets,
        value: jsn,
      );

      await hiveStore.deleteValue(walletHashId);

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Err?> deleteSeed({
    required String fingerprint,
    required SecureStorage secureStore,
  }) async {
    try {
      final (fingerprintIdxs, err) = await secureStore.getValue(StorageKeys.seeds);
      if (err != null) throw err;

      final fingerprintsJson = jsonDecode(fingerprintIdxs!)['wallets'] as List<dynamic>;

      final List<String> fingerprints = [];
      for (final fingerprint in fingerprintsJson) {
        fingerprints.add(fingerprint as String);
      }

      fingerprints.remove(fingerprint);

      final jsn = jsonEncode({
        'seeds': [...fingerprints]
      });

      final _ = await secureStore.saveValue(
        key: StorageKeys.seeds,
        value: jsn,
      );

      await secureStore.deleteValue(fingerprint);

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
