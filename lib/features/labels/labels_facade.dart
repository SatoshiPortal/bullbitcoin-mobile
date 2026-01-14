import 'package:bb_mobile/features/labels/application/store_label_dto.dart';
import 'package:bb_mobile/features/labels/domain/usecases/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/store_labels_usecase.dart';

export 'application/store_label_dto.dart';
export 'primitive/label_system.dart';
export 'primitive/label_type.dart';
export 'router.dart';
export 'locator.dart';

class LabelsFacade {
  final FetchLabelByReferenceUsecase _fetchLabelByReferenceUsecase;
  final FetchDistinctLabelsUsecase _fetchDistinctLabelsUsecase;
  final StoreLabelsUsecase _storeLabelsUsecase;

  LabelsFacade({
    required FetchLabelByReferenceUsecase fetchLabelByReferenceUsecase,
    required FetchDistinctLabelsUsecase fetchDistinctLabelsUsecase,
    required StoreLabelsUsecase storeLabelsUsecase,
  }) : _fetchLabelByReferenceUsecase = fetchLabelByReferenceUsecase,
       _fetchDistinctLabelsUsecase = fetchDistinctLabelsUsecase,
       _storeLabelsUsecase = storeLabelsUsecase;

  Future<List<String>> fetchByReference(String reference) async {
    final labels = await _fetchLabelByReferenceUsecase.execute(reference);
    return labels.map((label) => label.label).toList();
  }

  Future<Set<String>> fetch() async =>
      await _fetchDistinctLabelsUsecase.execute();

  Future<void> store(List<StoreLabelDto> labels) async =>
      await _storeLabelsUsecase.execute(labels);
}
