import 'package:bb_mobile/_core/data/datasources/seed_data_source.dart';
import 'package:bb_mobile/_core/data/models/seed_model.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';

class SeedRepositoryImpl implements SeedRepository {
  final SeedDataSource _source;

  const SeedRepositoryImpl({required SeedDataSource source}) : _source = source;

  @override
  Future<void> store({required String fingerprint, required Seed seed}) async {
    final model = SeedModel.fromEntity(seed);
    return _source.store(fingerprint: fingerprint, seed: model);
  }

  @override
  Future<Seed> get(String fingerprint) async {
    final model = await _source.get(fingerprint);
    return model.toEntity();
  }

  @override
  Future<bool> exists(String fingerprint) async {
    return _source.exists(fingerprint);
  }

  @override
  Future<void> delete(String fingerprint) async {
    return _source.delete(fingerprint);
  }
}
