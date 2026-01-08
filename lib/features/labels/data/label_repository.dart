import 'package:bb_mobile/features/labels/data/label_local_datasource.dart';
import 'package:bb_mobile/features/labels/data/label_row_mapper.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';

class LabelsRepository {
  final LabelsLocalDatasource _labelsLocalDatasource;

  LabelsRepository({required LabelsLocalDatasource labelDatasource})
    : _labelsLocalDatasource = labelDatasource;

  Future<void> store(List<Label> labels) async {
    final rows = labels
        .map((label) => LabelRowMapper.fromEntity(label))
        .toList();
    await _labelsLocalDatasource.store(rows);
  }

  Future<List<Label>> fetchByLabel(String label) async {
    final rows = await _labelsLocalDatasource.fetchByLabel(label);
    return rows.map((row) => row.toEntity()).toList();
  }

  Future<List<Label>> fetchByRef(String ref) async {
    final rows = await _labelsLocalDatasource.fetchByRef(ref);
    return rows.map((row) => row.toEntity()).toList();
  }

  Future<void> trashByLabel(String label) async {
    await _labelsLocalDatasource.trashByLabel(label);
  }

  Future<void> trashLabel(Label label) async {
    final row = LabelRowMapper.fromEntity(label);
    await _labelsLocalDatasource.trashByLabelAndRef(
      label: row.label,
      ref: row.ref,
    );
  }

  Future<List<Label>> fetchAll() async {
    final rows = await _labelsLocalDatasource.fetchAll();
    return rows.map((row) => row.toEntity()).toList();
  }

  Future<List<String>> fetchDistinct() async {
    return await _labelsLocalDatasource.fetchDistinct();
  }

  Future<void> trashAll() async => await _labelsLocalDatasource.trashAll();
}
