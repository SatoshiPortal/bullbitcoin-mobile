import 'package:bb_mobile/features/labels/application/store_label_model.dart';
import 'package:bb_mobile/features/labels/application/usecases/delete_label_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'label.dart';

export 'label.dart';
export 'domain/primitive/label_system.dart';
export 'domain/primitive/label_type.dart';
export 'router.dart';
export 'locator.dart';

class LabelsFacade {
  final FetchLabelByReferenceUsecase _fetchLabelByReferenceUsecase;
  final FetchDistinctLabelsUsecase _fetchDistinctLabelsUsecase;
  final StoreLabelsUsecase _storeLabelsUsecase;
  final DeleteLabelUsecase _deleteLabelUsecase;

  LabelsFacade({
    required FetchLabelByReferenceUsecase fetchLabelByReferenceUsecase,
    required FetchDistinctLabelsUsecase fetchDistinctLabelsUsecase,
    required StoreLabelsUsecase storeLabelsUsecase,
    required DeleteLabelUsecase deleteLabelUsecase,
  }) : _fetchLabelByReferenceUsecase = fetchLabelByReferenceUsecase,
       _fetchDistinctLabelsUsecase = fetchDistinctLabelsUsecase,
       _storeLabelsUsecase = storeLabelsUsecase,
       _deleteLabelUsecase = deleteLabelUsecase;

  Future<List<String>> fetchByReference(String reference) async {
    return await _fetchLabelByReferenceUsecase.execute(reference);
  }

  Future<Set<String>> fetch() async =>
      await _fetchDistinctLabelsUsecase.execute();

  Future<void> store(List<Label> labels) async {
    final models = labels
        .map(
          (label) => StoreLabelModel(
            type: label.type,
            label: label.label,
            reference: label.reference,
            origin: label.origin,
          ),
        )
        .toList();
    await _storeLabelsUsecase.execute(models);
  }

  Future<void> delete({
    required String label,
    required String reference,
  }) async =>
      await _deleteLabelUsecase.execute(label: label, reference: reference);
}
