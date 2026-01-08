import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';

class DriftSeedUsageRepository implements SeedUsageRepositoryPort {
  final SqliteDatabase _database;

  DriftSeedUsageRepository(this._database);

  @override
  Future<SeedUsage> add({
    required String fingerprint,
    required SeedUsagePurpose purpose,
    required String consumerRef,
  }) {
    // TODO: implement add
    throw UnimplementedError();
  }

  @override
  Future<void> deleteById(int id) {
    // TODO: implement deleteById
    throw UnimplementedError();
  }

  @override
  Future<bool> isUsed(String fingerprint) {
    // TODO: implement isUsed
    throw UnimplementedError();
  }
}
