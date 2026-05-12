import 'dart:convert';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/foundation.dart';

class SeedDatasource {
  final KeyValueStorageDatasource<String> _secureStorage;

  const SeedDatasource({
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _secureStorage = secureStorage;

  Future<void> store({required String fingerprint, required SeedModel seed}) {
    final key = composeSeedStorageKey(fingerprint);
    final value = jsonEncode(seed.toJson());
    return _secureStorage.saveValue(key: key, value: value);
  }

  Future<SeedModel> get(String fingerprint) async {
    const maxRetries = 5;
    const initialDelay = Duration(milliseconds: 300);
    final key = composeSeedStorageKey(fingerprint);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final value = await _secureStorage.getValue(key);
        if (value != null) {
          final json = jsonDecode(value) as Map<String, dynamic>;
          final seed = SeedModel.fromJson(json);
          if (attempt > 0) {
            log.fine(
              'Seed found for fingerprint $fingerprint on attempt ${attempt + 1}',
            );
          }
          return seed;
        }

        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: initialDelay.inMilliseconds * (1 << attempt),
          );
          log.fine(
            'Seed read returned null for fingerprint $fingerprint on attempt ${attempt + 1}, retrying in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
          continue;
        }

        throw SeedNotFoundException(
          'Seed not found for fingerprint: $fingerprint',
        );
      } catch (e) {
        if (e is SeedNotFoundException) rethrow;

        // CRITICAL: rethrow KeychainLockedException without retrying or
        // converting it.
        //
        // The iOS Keychain returns `errSecInteractionNotAllowed` (-25308)
        // when the device has not been unlocked since boot AND the
        // item's accessibility class requires post-unlock access (BULL
        // uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` —
        // see `lib/core/storage/storage_locator.dart`). The secure
        // storage layer maps this to `KeychainLockedException` (see
        // `keychain_locked_exception.dart`).
        //
        // Why this matters here specifically:
        //  - The retry loop below cannot help. The lock state clears
        //    only on user unlock action, not on backoff; retrying 5×
        //    with exponential delay just burns ~9.6s of wall clock
        //    while every attempt hits the same locked keychain.
        //  - The fallback at the end of this catch throws
        //    `SeedNotFoundException`. If we let `KeychainLockedException`
        //    flow through that path, downstream code (e.g.
        //    `CheckForExistingDefaultWalletsUsecase`,
        //    `RequiresMigrationUsecase`) interprets the result as
        //    "wallet seed is missing" and may trigger destructive
        //    recovery flows for what is actually a transient, self-
        //    healing state (resolves when the user unlocks).
        //
        // Letting the typed exception bubble up to the UI is the
        // correct behavior — the UI can surface a "device just
        // unlocked, please retry" prompt or simply re-call the
        // operation on next state change.
        if (e is KeychainLockedException) rethrow;

        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: initialDelay.inMilliseconds * (1 << attempt),
          );
          log.fine(
            'Exception reading seed for fingerprint $fingerprint on attempt ${attempt + 1}: $e, retrying in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
          continue;
        }

        log.severe(
          message: 'Failed to read seed after $maxRetries attempts',
          error: e,
          trace: StackTrace.current,
        );
        throw SeedNotFoundException(
          'Seed not found for fingerprint: $fingerprint',
        );
      }
    }

    throw SeedNotFoundException('Seed not found for fingerprint: $fingerprint');
  }

  Future<bool> exists(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _secureStorage.hasValue(key);
  }

  Future<void> delete(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _secureStorage.deleteValue(key);
  }

  Future<List<SeedModel>> getAll() async {
    final allEntries = await _secureStorage.getAll();
    // Top-level function for isolate processing
    @pragma('vm:entry-point')
    List<SeedModel> parseSeedsInIsolate(Map<String, String> allEntries) {
      final seeds = <SeedModel>[];

      for (final entry in allEntries.entries) {
        try {
          final key = entry.key;
          final value = entry.value;
          if (value.isEmpty) continue;

          // Only process keys that start with the seed prefix
          if (!key.startsWith(SecureStorageKeyPrefixConstants.seed)) {
            continue;
          }

          // Try to parse as SeedModel JSON
          final json = jsonDecode(value) as Map<String, dynamic>;
          final seedModel = SeedModel.fromJson(json);
          seeds.add(seedModel);
        } catch (e) {
          // Skip keys that are not seed objects
          continue;
        }
      }

      return seeds;
    }

    // Parse entries in isolate to avoid blocking UI
    return await compute(parseSeedsInIsolate, allEntries);
  }

  static String composeSeedStorageKey(String fingerprint) =>
      '${SecureStorageKeyPrefixConstants.seed}$fingerprint';
}

class SeedNotFoundException extends BullException {
  SeedNotFoundException(super.message);
}
