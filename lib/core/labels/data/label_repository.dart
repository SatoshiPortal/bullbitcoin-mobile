import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';

class LabelRepository {
  final LabelStorageDatasource _labelStorageDatasource;

  LabelRepository({
    required LabelStorageDatasource labelStorageDatasource,
  }) : _labelStorageDatasource = labelStorageDatasource;

  Future<void> store<T extends Labelable>({
    required String label,
    required T labelable,
    String? origin,
    bool? spendable,
  }) async {
    await _labelStorageDatasource.store(
      LabelModel(
        label: label,
        type: LabelType.fromLabelable(labelable).name,
        ref: labelable.labelRef,
        origin: origin,
        spendable: spendable,
      ),
    );
  }

  Future<List<Label>> fetchByLabel({required String label}) async {
    final labelModels = await _labelStorageDatasource.fetchByLabel(label);
    return labelModels
        .map(
          (model) => Label(
            type: LabelType.fromName(model.type),
            label: model.label,
            origin: model.origin,
          ),
        )
        .toList();
  }

  Future<List<Label>> fetchByEntity<T extends Labelable>({
    required T labelable,
  }) async {
    final type = LabelType.fromLabelable(labelable);
    final labelModels =
        await _labelStorageDatasource.fetchByRef(type.name, labelable.labelRef);
    return labelModels
        .map(
          (model) => Label(
              type: LabelType.fromName(model.type),
              label: model.label,
              origin: model.origin),
        )
        .toList();
  }

  /// Trash the label and all entities related
  Future<void> trash({required String label}) async {
    await _labelStorageDatasource.trash(label);
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _labelStorageDatasource.fetchAll();
    return labelModels
        .map(
          (model) => Label(
            type: LabelType.fromName(model.type),
            label: model.label,
            origin: model.origin,
            spendable: model.spendable,
          ),
        )
        .toList();
  }
}
