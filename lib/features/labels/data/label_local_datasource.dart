import 'package:bb_mobile/core/storage/storage.dart';

class LabelsLocalDatasource {
  final SqliteDatabase _database;

  LabelsLocalDatasource(this._database);

  Future<void> store(List<LabelRow> rows) {
    return _database.batch(
      (batch) => batch.insertAll(
        _database.labels,
        rows.map((r) => r.toCompanion(true)).toList(),
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  Future<List<LabelRow>> fetchByLabel(String label) {
    return _database.managers.labels.filter((l) => l.label(label)).get();
  }

  Future<List<LabelRow>> fetchByRef(String ref) {
    return _database.managers.labels.filter((l) => l.ref(ref)).get();
  }

  Future<List<LabelRow>> fetchAll() {
    return _database.managers.labels.get();
  }

  Future<List<String>> fetchDistinct() async {
    final rows = await (_database.selectOnly(
      _database.labels,
      distinct: true,
    )..addColumns([_database.labels.label])).get();
    return rows
        .map((row) => row.read<String>(_database.labels.label)!)
        .toList();
  }

  Future<void> trashByLabel(String label) {
    return _database.managers.labels.filter((l) => l.label(label)).delete();
  }

  Future<void> trashByRef(String ref) {
    return _database.managers.labels.filter((l) => l.ref(ref)).delete();
  }

  Future<void> trashByLabelAndRef({
    required String label,
    required String ref,
  }) {
    return _database.managers.labels
        .filter((l) => l.ref(ref) & l.label(label))
        .delete();
  }

  Future<void> trashAll() {
    return _database.delete(_database.labels).go();
  }
}
