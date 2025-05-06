import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:drift/drift.dart';

class LabelDatasource {
  final SqliteDatabase _sqlite;

  LabelDatasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<void> store<T extends Labelable>({
    required String label,
    required T entity,
    String? origin,
    bool? spendable,
  }) async {
    await _sqlite.managers.labels.create(
      (l) => l(
        label: label,
        type: LabelableEntity.fromLabelable(entity),
        ref: entity.labelRef,
        origin: Value(origin),
        spendable: Value(spendable),
      ),
    );
  }

  Future<List<LabelModel>> fetchByLabel({required String label}) async {
    final labelModels =
        await _sqlite.managers.labels.filter((l) => l.label(label)).get();
    return labelModels.map((row) => LabelModelMapper.fromSqlite(row)).toList();
  }

  Future<List<LabelModel>> fetchByEntity<T extends Labelable>({
    required T entity,
  }) async {
    final labelModels =
        await _sqlite.managers.labels
            .filter((l) => l.ref(entity.labelRef))
            .get();
    return labelModels.map((row) => LabelModelMapper.fromSqlite(row)).toList();
  }

  Future<void> trashByLabel({required String label}) async {
    await _sqlite.managers.labels.filter((l) => l.label(label)).delete();
  }

  Future<void> trashByEntity<T extends Labelable>({required T entity}) async {
    await _sqlite.managers.labels
        .filter((l) => l.ref(entity.labelRef))
        .delete();
  }

  Future<void> trashOneLabel<T extends Labelable>({
    required T entity,
    required String label,
  }) async {
    await _sqlite.managers.labels
        .filter((l) => l.ref(entity.labelRef) & l.label(label))
        .delete();
  }

  Future<List<LabelModel>> fetchAll() async {
    final labelModels = await _sqlite.managers.labels.get();
    return labelModels.map((row) => LabelModelMapper.fromSqlite(row)).toList();
  }

  Future<void> trashAll() async {
    await _sqlite.delete(_sqlite.labels).go();
  }
}
