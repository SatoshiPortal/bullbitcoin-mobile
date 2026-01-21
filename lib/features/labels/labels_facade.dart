import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/store_label_application.dart';
import 'package:bb_mobile/features/labels/application/usecases/delete_label_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/new_label.dart';
import 'package:bb_mobile/features/labels/label.dart';

export 'package:bb_mobile/features/labels/label.dart';
export 'package:bb_mobile/features/labels/new_label.dart';
export 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
export 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
export 'package:bb_mobile/features/labels/router.dart';
export 'package:bb_mobile/features/labels/locator.dart';
export 'package:bb_mobile/features/labels/ui/page.dart';
export 'package:bb_mobile/features/labels/ui/label_text.dart';
export 'package:bb_mobile/features/labels/ui/labeled_text_input.dart';
export 'package:bb_mobile/features/labels/ui/labels_widget.dart';

class LabelsFacade {
  final FetchLabelByReferenceUsecase _fetchLabelByReferenceUsecase;
  final FetchAllLabelsUsecase _fetchAllLabelsUsecase;
  final StoreLabelUsecase _storeLabelsUsecase;
  final DeleteLabelUsecase _deleteLabelUsecase;

  LabelsFacade({
    required FetchLabelByReferenceUsecase fetchLabelByReferenceUsecase,
    required FetchAllLabelsUsecase fetchAllLabelsUsecase,
    required StoreLabelUsecase storeLabelsUsecase,
    required DeleteLabelUsecase deleteLabelUsecase,
  }) : _fetchLabelByReferenceUsecase = fetchLabelByReferenceUsecase,
       _fetchAllLabelsUsecase = fetchAllLabelsUsecase,
       _storeLabelsUsecase = storeLabelsUsecase,
       _deleteLabelUsecase = deleteLabelUsecase;

  Future<List<Label>> fetchByReference(String reference) async {
    final labels = await _fetchLabelByReferenceUsecase.execute(reference);
    return labels
        .map((label) => LabelMapper.applicationLabelToLabel(label))
        .toList();
  }

  Future<List<Label>> fetchAll() async {
    final labels = await _fetchAllLabelsUsecase.execute();
    return labels
        .map((label) => LabelMapper.applicationLabelToLabel(label))
        .toList();
  }

  Future<Label> store(NewLabel label) async {
    final storedLabel = await _storeLabelsUsecase.execute(
      NewApplicationLabel(
        type: label.type,
        label: label.label,
        reference: label.reference,
        origin: label.origin,
      ),
    );
    return LabelMapper.applicationLabelToLabel(storedLabel);
  }

  Future<void> delete(Label label) async => await _deleteLabelUsecase.execute(
    LabelMapper.labelToApplicationLabel(label),
  );
}
