import 'package:bb_mobile/core/seed/data/models/bip85_mapping_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

abstract class Bip85MappingDatasource {
  Future<void> store(Bip85MappingModel model);
  Future<Bip85MappingModel?> fetch(String seedFingerprint);
  Future<List<Bip85MappingModel>> fetchAll({String? masterSeedFingerprint});
  Future<void> delete(String seedFingerprint);
}

class Bip85MappingDriftDatasource implements Bip85MappingDatasource {
  final SqliteDatabase _db;

  const Bip85MappingDriftDatasource({required SqliteDatabase db}) : _db = db;

  @override
  Future<void> store(Bip85MappingModel model) async {
    final row = model.toTableRow();
    await _db.into(_db.bip85Mappings).insertOnConflictUpdate(row);
  }

  @override
  Future<Bip85MappingModel?> fetch(String seedFingerprint) async {
    final row =
        await _db.managers.bip85Mappings
            .filter((f) => f.seedFingerprint(seedFingerprint))
            .getSingleOrNull();

    if (row == null) return null;
    return Bip85MappingModel.fromTableRow(row);
  }

  @override
  Future<List<Bip85MappingModel>> fetchAll({
    String? masterSeedFingerprint,
  }) async {
    final rows =
        await _db.managers.bip85Mappings
            .filter((f) => f.masterSeedFingerprint(masterSeedFingerprint))
            .get();

    return rows.map((e) => Bip85MappingModel.fromTableRow(e)).toList();
  }

  @override
  Future<void> delete(String seedFingerprint) async {
    await _db.managers.bip85Mappings
        .filter((f) => f.seedFingerprint(seedFingerprint))
        .delete();
  }
}
