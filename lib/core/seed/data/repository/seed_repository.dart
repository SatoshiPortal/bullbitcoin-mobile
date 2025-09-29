import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SeedRepository {
  final SeedDatasource _source;

  const SeedRepository({required SeedDatasource source}) : _source = source;

  Future<void> store({required Seed seed}) async {
    try {
      await _source.store(
        fingerprint: seed.masterFingerprint,
        seed: SeedModel.fromEntity(seed),
      );
    } catch (e, stackTrace) {
      log.info(
        'Failed to create seed from mnemonic: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Seed> get(String fingerprint) async {
    try {
      final model = await _source.get(fingerprint);
      return model.toEntity();
    } catch (e, stackTrace) {
      log.info(
        'Failed to get seed with fingerprint $fingerprint: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> exists(String fingerprint) async {
    try {
      return await _source.exists(fingerprint);
    } catch (e, stackTrace) {
      log.info(
        'Failed to check if seed exists with fingerprint $fingerprint: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> delete(String fingerprint) => _source.delete(fingerprint);
}
