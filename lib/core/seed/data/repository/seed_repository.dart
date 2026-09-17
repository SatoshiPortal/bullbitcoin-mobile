import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';

/// Read-only access to a stored seed, kept for the silent payments feature
/// until it derives its keys through `secrets`. See [SeedDatasource].
class SeedRepository {
  final SeedDatasource _source;

  const SeedRepository({required this._source});

  Future<Seed> get(String fingerprint) async {
    try {
      final model = await _source.get(fingerprint);
      // Run toEntity() in isolate to avoid blocking UI with PBKDF2 + bip32
      final entity = await compute(_toEntityInIsolate, model);
      return entity;
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to get seed with fingerprint',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Seed _toEntityInIsolate(SeedModel model) => model.toEntity();
}
