import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_usage/seed_usage_mappers.dart';
import 'package:drift/drift.dart';

class DriftSeedUsageRepository implements SeedUsageRepositoryPort {
  final SqliteDatabase _database;

  DriftSeedUsageRepository({required SqliteDatabase database})
    : _database = database;

  @override
  Future<SeedUsage> add({
    required String fingerprint,
    required SeedUsagePurpose purpose,
    required String consumerRef,
  }) async {
    final seedUsageRow = await _database.managers.seedUsages.createReturning(
      (o) => o(
        fingerprint: fingerprint,
        purpose: purpose,
        consumerRef: consumerRef,
      ),
    );

    return seedUsageRow.toDomain();
  }

  @override
  Future<bool> isUsed(String fingerprint) async {
    final count = await _database.managers.seedUsages
        .filter((f) => f.fingerprint(fingerprint))
        .count();

    return count > 0;
  }

  @override
  Future<SeedUsage?> getByConsumer({
    required SeedUsagePurpose purpose,
    required String consumerRef,
  }) async {
    final row = await _database.managers.seedUsages
        .filter((f) => f.purpose(purpose) & f.consumerRef(consumerRef))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<SeedUsage>> getAll() async {
    final rows = await _database.managers.seedUsages.get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> deleteById(int id) async {
    await _database.managers.seedUsages.filter((f) => f.id(id)).delete();
  }
}
