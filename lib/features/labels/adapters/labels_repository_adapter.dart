import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';

class DriftLabelsRepositoryAdapter implements LabelsRepositoryPort {
  final SqliteDatabase _database;

  DriftLabelsRepositoryAdapter({required SqliteDatabase database})
    : _database = database;

  @override
  Future<void> store(List<LabelEntity> labels) async {
    final rows = labels.map((label) => LabelMapper.fromEntity(label)).toList();
    await _database.batch(
      (batch) => batch.insertAll(
        _database.labels,
        rows,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  @override
  Future<List<LabelEntity>> fetchByLabel(String label) async {
    final rows = await _database.managers.labels
        .filter((l) => l.label(label))
        .get();
    return rows.map((row) => LabelMapper.toEntity(row)).toList();
  }

  @override
  Future<List<LabelEntity>> fetchByReference(String reference) async {
    final rows = await _database.managers.labels
        .filter((l) => l.reference(reference))
        .get();
    return rows.map((row) => LabelMapper.toEntity(row)).toList();
  }

  @override
  Future<void> trashLabel({
    required String label,
    required String reference,
  }) async {
    await _database.managers.labels
        .filter((l) => l.reference(reference) & l.label(label))
        .delete();
  }

  @override
  Future<List<LabelEntity>> fetchAll() async {
    final rows = await _database.managers.labels.get();
    return rows.map((row) => LabelMapper.toEntity(row)).toList();
  }
}
