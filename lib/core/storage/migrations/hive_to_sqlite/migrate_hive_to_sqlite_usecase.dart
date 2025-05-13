import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:flutter/foundation.dart';

class MigrateHiveToSqliteUsecase {
  final SqliteDatabase _sqliteDatabase;
  final NewSeedRepository _newSeedRepository;
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;

  MigrateHiveToSqliteUsecase({
    required SqliteDatabase sqliteDatabase,
    required NewSeedRepository newSeedRepository,
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
  }) : _sqliteDatabase = sqliteDatabase,
       _newSeedRepository = newSeedRepository,
       _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository;

  Future<bool> execute() async {
    try {
      final settings = await _sqliteDatabase.managers.settings.get();
      if (settings.isNotEmpty) {
        debugPrint('skipping migration: sqlite settings already exists');
        return false;
      }

      final oldWallets = await _oldWalletRepository.fetch();
      final oldFingerprints = oldWallets.map((e) => e.mnemonicFingerprint);
      final seedsImported = await _storeNewSeeds(oldFingerprints.toList());
      debugPrint('migration: $seedsImported/${oldWallets.length} seeds');

      return true;
    } catch (e) {
      debugPrint('migration failed: $e');
      return false;
    }
  }

  Future<int> _storeNewSeeds(List<String> oldFingerprints) async {
    int count = 0;

    for (final oldFingerprint in oldFingerprints) {
      try {
        final oldSeed = await _oldSeedRepository.fetch(
          fingerprint: oldFingerprint,
        );
        final seed = NewSeedEntity.mnemonic(
          mnemonicWords: oldSeed.mnemonicList(),
        );
        await _newSeedRepository.store(
          fingerprint: seed.masterFingerprint,
          seed: seed,
        );
        count++;
      } catch (e) {
        debugPrint('SKIP: $e');
        continue;
      }
    }

    return count;
  }
}
