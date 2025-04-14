import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/data/labelable.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';

class LabelRepository {
  final LabelStorageDatasource _labelStorageDatasource;

  LabelRepository({
    required LabelStorageDatasource labelStorageDatasource,
  }) : _labelStorageDatasource = labelStorageDatasource;

  Future<void> store<T extends Labelable>({
    required String label,
    required T entity,
    String? origin,
    bool? spendable,
  }) async {
    await _labelStorageDatasource.store(
      LabelModel(
        label: label,
        type: Entity.fromLabelable(entity),
        ref: entity.toRef(),
        origin: origin,
        spendable: spendable,
      ),
    );
  }

  Future<List<Label>> fetchByLabel({required String label}) async {
    final labelModels = await _labelStorageDatasource.fetchByLabel(label);
    return labelModels
        .map((model) => Label(label: model.label, origin: model.origin))
        .toList();
  }

  Future<List<Label>> fetchByEntity<T extends Labelable>(
      {required T entity}) async {
    final prefix = Entity.fromLabelable(entity);
    final labelModels =
        await _labelStorageDatasource.fetchByRef(prefix, entity.toRef());
    return labelModels
        .map((model) => Label(label: model.label, origin: model.origin))
        .toList();
  }

  /// Trash the label and all entities related
  Future<void> trash({required String label}) async {
    await _labelStorageDatasource.trash(label);
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _labelStorageDatasource.fetchAll();
    return labelModels
        .map((model) => Label(
              label: model.label,
              origin: model.origin,
              spendable: model.spendable,
            ))
        .toList();
  }
}
