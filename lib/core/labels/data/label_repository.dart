// import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
// import 'package:bb_mobile/core/labels/domain/label_entity.dart';

// class LabelRepository {
//   final LabelStorageDatasource _mainLabelStorage;
//   final LabelStorageDatasource _refLabelStorage;

//   LabelRepository({
//     required LabelStorageDatasource mainLabelStorage,
//     required LabelStorageDatasource refLabelStorage,
//   })  : _mainLabelStorage = mainLabelStorage,
//         _refLabelStorage = refLabelStorage;

//   Future<void> createLabel(Label label) async {
//     try {
//       await _labelStorage.create(label);
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<void> deleteLabelForRef(
//     String label,
//     String ref,
//     LabelType type,
//   ) async {
//     try {
//       await _labelStorage.deleteLabelForRef(label, ref, type);
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<List<Label>?> getAllLabels() async {
//     try {
//       return await _labelStorage.readAll();
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<List<Label>?> getLabelsByRef(String ref) async {
//     try {
//       return await _labelStorage.readByRef(ref);
//     } catch (e) {
//       rethrow;
//     }
//   }
// }
