import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/app_startup/domain/legacy_seed.dart';

class GetLegacySeedsUsecase {
  final KeyValueStorageDatasource<String> _secureStorage;

  GetLegacySeedsUsecase({required this._secureStorage});

  /// Enumerates legacy seeds straight from secure storage — no Hive: the old
  /// app stored the seed material itself (keyed by fingerprint) there; Hive
  /// only held the wallet index.
  @useResult
  Future<Result<List<LegacySeed>, AppStartupFailure>> execute() async {
    try {
      final entries = await _secureStorage.getAll();
      return Ok([
        for (final entry in entries.entries)
          ?LegacySeed.tryFromSecureStorageEntry(entry.key, entry.value),
      ]);
    } on Object catch (e, st) {
      log.severe(
        message: 'Legacy seed enumeration failed',
        error: e,
        trace: st,
      );
      return const Err(AppStartupLegacySeedsFailure());
    }
  }
}
