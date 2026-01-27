import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

class DriftLabelsRepositoryAdapter implements LabelsRepositoryPort {
  final SqliteDatabase _database;

  DriftLabelsRepositoryAdapter({required SqliteDatabase database})
    : _database = database;

  @override
  Future<LabelEntity> store(NewLabel newLabel) async {
    final companion = LabelMapper.newLabelEntityToCompanion(newLabel);
    final id = await _database
        .into(_database.labels)
        .insertOnConflictUpdate(companion);

    return LabelEntity(
      id: id,
      type: newLabel.type,
      label: newLabel.label,
      reference: newLabel.reference,
      origin: newLabel.origin,
    );
  }

  @override
  Future<List<LabelEntity>> fetchByLabel(String label) async {
    final rows = await _database.managers.labels
        .filter((l) => l.label(label))
        .get();
    return rows.map((row) => LabelMapper.toLabelEntity(row)).toList();
  }

  @override
  Future<List<LabelEntity>> fetchByReference(String reference) async {
    final rows = await _database.managers.labels
        .filter((l) => l.reference(reference))
        .get();
    return rows.map((row) => LabelMapper.toLabelEntity(row)).toList();
  }

  @override
  Future<LabelEntity?> fetchById(int id) async {
    final row = await _database.managers.labels
        .filter((l) => l.id(id))
        .getSingleOrNull();
    return row != null ? LabelMapper.toLabelEntity(row) : null;
  }

  @override
  Future<void> trash(int id) async {
    await _database.managers.labels.filter((l) => l.id(id)).delete();
  }

  @override
  Future<List<LabelEntity>> fetchAll() async {
    final rows = await _database.managers.labels.get();
    return rows.map((row) => LabelMapper.toLabelEntity(row)).toList();
  }
}
