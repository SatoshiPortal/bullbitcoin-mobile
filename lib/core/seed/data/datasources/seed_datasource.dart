import 'dart:convert';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
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
    const initialDelay = Duration(milliseconds: 500);
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
        if (e is SeedNotFoundException) {
          rethrow;
        }

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
    const maxRetries = 5;
    const initialDelay = Duration(milliseconds: 500);

    log.fine('Attempting to fetch all seeds from secure storage');

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

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final allEntries = await _secureStorage.getAll();
        log.fine(
          'Secure storage returned ${allEntries.length} total entries on attempt ${attempt + 1}',
        );

        final seedEntries = allEntries.entries
            .where(
              (e) => e.key.startsWith(SecureStorageKeyPrefixConstants.seed),
            )
            .toList();
        log.fine('Found ${seedEntries.length} seed entries');

        // If we got entries or it's the last attempt, proceed with parsing
        if (allEntries.isNotEmpty || attempt == maxRetries - 1) {
          final seeds = await compute(parseSeedsInIsolate, allEntries);
          if (attempt > 0) {
            log.fine('Successfully retrieved seeds on attempt ${attempt + 1}');
          }
          return seeds;
        }

        // Empty result might mean storage not ready, retry
        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: initialDelay.inMilliseconds * (1 << attempt),
          );
          log.fine(
            'Secure storage returned empty on attempt ${attempt + 1}, retrying in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
        }
      } catch (e) {
        if (attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: initialDelay.inMilliseconds * (1 << attempt),
          );
          log.fine(
            'Exception fetching all seeds on attempt ${attempt + 1}: $e, retrying in ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
          continue;
        }

        log.severe(
          message: 'Failed to fetch all seeds after $maxRetries attempts',
          error: e,
          trace: StackTrace.current,
        );
        rethrow;
      }
    }

    // If all retries exhausted and storage was empty, return empty list
    log.fine('All retry attempts exhausted, returning empty list');
    return [];
  }

  static String composeSeedStorageKey(String fingerprint) =>
      '${SecureStorageKeyPrefixConstants.seed}$fingerprint';
}

class SeedNotFoundException extends BullException {
  SeedNotFoundException(super.message);
}
