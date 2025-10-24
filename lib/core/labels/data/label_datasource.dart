import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class LabelDatasource {
  final SqliteDatabase _sqlite;

  LabelDatasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<void> store(LabelModel label) async {
    await _sqlite.managers.labels.create(
      (l) => l(
        label: label.label,
        type: label.type,
        ref: label.ref,
        origin: Value(label.origin),
        spendable: Value(label.spendable),
      ),
    );
  }

  Future<void> batch(List<LabelModel> labels) async {
    final rows = labels.map((label) => label.toSqlite()).toList();
    await _sqlite.batch(
      (batch) => batch.insertAll(
        _sqlite.labels,
        rows,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  Future<List<LabelModel>> fetchByLabel({required String label}) async {
    final labelModels =
        await _sqlite.managers.labels.filter((l) => l.label(label)).get();
    return labelModels.map((row) => LabelModel.fromSqlite(row)).toList();
  }

  Future<List<LabelModel>> fetchByRef(String ref) async {
    final labelModels =
        await _sqlite.managers.labels.filter((l) => l.ref(ref)).get();
    return labelModels.map((row) => LabelModel.fromSqlite(row)).toList();
  }

  Future<void> trashByLabel({required String label}) async {
    await _sqlite.managers.labels.filter((l) => l.label(label)).delete();
  }

  Future<void> trashByRef(String ref) async {
    await _sqlite.managers.labels.filter((l) => l.ref(ref)).delete();
  }

  Future<void> trashLabel(LabelModel label) async {
    await _sqlite.managers.labels
        .filter((l) => l.ref(label.ref) & l.label(label.label))
        .delete();
  }

  Future<List<LabelModel>> fetchAll() async {
    final labelModels = await _sqlite.managers.labels.get();
    return labelModels.map((row) => LabelModel.fromSqlite(row)).toList();
  }

  Future<void> trashAll() async {
    await _sqlite.delete(_sqlite.labels).go();
  }
}
