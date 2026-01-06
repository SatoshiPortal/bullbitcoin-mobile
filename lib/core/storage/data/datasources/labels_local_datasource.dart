part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Labels])
class LabelsLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$LabelsLocalDatasourceMixin {
  LabelsLocalDatasource(super.attachedDatabase);

  Future<void> store(LabelRow row) {
    return into(labels).insert(row.toCompanion(true));
  }

  Future<void> storeBatch(List<LabelRow> rows) {
    return batch(
      (batch) => batch.insertAll(
        labels,
        rows.map((r) => r.toCompanion(true)).toList(),
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  Future<List<LabelRow>> fetchByLabel(String label) {
    return attachedDatabase.managers.labels.filter((l) => l.label(label)).get();
  }

  Future<List<LabelRow>> fetchByRef(String ref) {
    return attachedDatabase.managers.labels.filter((l) => l.ref(ref)).get();
  }

  Future<List<LabelRow>> fetchAll() {
    return attachedDatabase.managers.labels.get();
  }

  Future<List<String>> fetchDistinctLabels() async {
    final rows = await (selectOnly(
      labels,
      distinct: true,
    )..addColumns([labels.label])).get();
    return rows.map((row) => row.read<String>(labels.label)!).toList();
  }

  Future<void> trashByLabel(String label) {
    return attachedDatabase.managers.labels
        .filter((l) => l.label(label))
        .delete();
  }

  Future<void> trashByRef(String ref) {
    return attachedDatabase.managers.labels.filter((l) => l.ref(ref)).delete();
  }

  Future<void> trashByLabelAndRef({
    required String label,
    required String ref,
  }) {
    return attachedDatabase.managers.labels
        .filter((l) => l.ref(ref) & l.label(label))
        .delete();
  }

  Future<void> trashAll() {
    return delete(labels).go();
  }
}
