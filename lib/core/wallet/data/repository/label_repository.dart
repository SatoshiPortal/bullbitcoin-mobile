import 'package:bb_mobile/core/wallet/data/datasources/label_storage_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entity/labels.dart';

class LabelRepository {
  final LabelStorageDatasource _labelStorage;

  LabelRepository({
    required LabelStorageDatasource labelStorage,
  }) : _labelStorage = labelStorage;

  Future<void> createLabel(Label label) async {
    try {
      await _labelStorage.create(label);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLabelForRef(
    String label,
    String ref,
    LabelType type,
  ) async {
    try {
      await _labelStorage.deleteLabelForRef(label, ref, type);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Label>?> getAllLabels() async {
    try {
      return await _labelStorage.readAll();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Label>?> getLabelsByRef(String ref) async {
    try {
      return await _labelStorage.readByRef(ref);
    } catch (e) {
      rethrow;
    }
  }
}
