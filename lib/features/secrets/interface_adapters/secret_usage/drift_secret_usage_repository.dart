import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secret_usage/secret_usage_mappers.dart';
import 'package:drift/drift.dart';

class DriftSecretUsageRepository implements SecretUsageRepositoryPort {
  final SqliteDatabase _database;

  DriftSecretUsageRepository({required SqliteDatabase database})
    : _database = database;

  @override
  Future<SecretUsage> add({
    required String fingerprint,
    required SecretUsagePurpose purpose,
    required String consumerRef,
  }) async {
    final seedUsageRow = await _database.managers.secretUsages.createReturning(
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
    final count = await _database.managers.secretUsages
        .filter((f) => f.fingerprint(fingerprint))
        .count();

    return count > 0;
  }

  @override
  Future<SecretUsage?> getByConsumer({
    required SecretUsagePurpose purpose,
    required String consumerRef,
  }) async {
    final row = await _database.managers.secretUsages
        .filter((f) => f.purpose(purpose) & f.consumerRef(consumerRef))
        .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<SecretUsage>> getAll() async {
    final rows = await _database.managers.secretUsages.get();
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<void> deleteById(int id) async {
    await _database.managers.secretUsages.filter((f) => f.id(id)).delete();
  }
}
