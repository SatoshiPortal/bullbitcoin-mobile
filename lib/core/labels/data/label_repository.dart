import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';

class LabelRepository {
  final LabelDatasource _labelDatasource;

  LabelRepository({required LabelDatasource labelDatasource})
    : _labelDatasource = labelDatasource;

  Future<void> store<T extends Labelable>({
    required String label,
    required T entity,
    String? origin,
    bool? spendable,
  }) async {
    await _labelDatasource.store(
      label: label,
      entity: entity,
      origin: origin,
      spendable: spendable,
    );
  }

  Future<List<Label>> fetchByLabel({required String label}) async {
    final labelModels = await _labelDatasource.fetchByLabel(label: label);
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<List<Label>> fetchByEntity<T extends Labelable>({
    required T entity,
  }) async {
    final labelModels = await _labelDatasource.fetchByEntity(entity: entity);
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashByLabel({required String label}) async {
    await _labelDatasource.trashByLabel(label: label);
  }

  Future<void> trashByEntity<T extends Labelable>({required T entity}) async {
    await _labelDatasource.trashByEntity(entity: entity);
  }

  Future<void> trashOneLabel<T extends Labelable>({
    required T entity,
    required String label,
  }) async {
    await _labelDatasource.trashOneLabel(entity: entity, label: label);
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _labelDatasource.fetchAll();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashAll() async {
    await _labelDatasource.trashAll();
  }
}
