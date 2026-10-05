import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_store_type_repository.dart';

class SeedStoreTypeRepositoryImpl implements SeedStoreTypeRepository {
  final SeedStoreTypeDatasource _datasource;

  const SeedStoreTypeRepositoryImpl(this._datasource);

  @override
  Future<SeedStoreType?> fetch() async {
    final model = await _datasource.read();
    return model?.toEntity();
  }
}
