import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/app_startup/domain/legacy_seed.dart';

class GetLegacySeedsUsecase {
  final KeyValueStorageDatasource<String> _secureStorage;

  GetLegacySeedsUsecase({required this._secureStorage});

  /// Enumerates legacy seeds straight from secure storage — no Hive: the old
  /// app stored the seed material itself (keyed by fingerprint) there; Hive
  /// only held the wallet index.
  Future<List<LegacySeed>> execute() async {
    final entries = await _secureStorage.getAll();
    return [
      for (final entry in entries.entries)
        ?LegacySeed.tryFromSecureStorageEntry(entry.key, entry.value),
    ];
  }
}
