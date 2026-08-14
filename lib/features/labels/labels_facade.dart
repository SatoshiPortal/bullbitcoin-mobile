import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/store_label_application.dart';
import 'package:bb_mobile/features/labels/application/usecases/trash_label_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/new_label.dart';
import 'package:bb_mobile/features/labels/label.dart';

export 'package:bb_mobile/features/labels/label.dart';
export 'package:bb_mobile/features/labels/new_label.dart';
export 'package:bb_mobile/features/labels/domain/label_failure.dart';
export 'package:bb_mobile/features/labels/presentation/label_failure_l10n.dart';
export 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
export 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
export 'package:bb_mobile/features/labels/router.dart';
export 'package:bb_mobile/features/labels/locator.dart';
export 'package:bb_mobile/features/labels/ui/page.dart';
export 'package:bb_mobile/features/labels/ui/label_text.dart';
export 'package:bb_mobile/features/labels/ui/labels_widget.dart';

/// Public contract of the labels feature.
///
/// **Reads are best-effort**: labels are non-critical metadata that enrich
/// addresses/transactions, so a lookup failure degrades to an empty result
/// (logged at the boundary) rather than aborting the caller's flow. **Writes
/// return [Result]** so the caller can decide what a persistence failure means
/// for its own flow. The facade itself never throws and never surfaces a raw
/// reason — callers translate a [LabelFailure] via its presentation extension.
class LabelsFacade {
  final FetchLabelByReferenceUsecase _fetchLabelByReferenceUsecase;
  final FetchAllLabelsUsecase _fetchAllLabelsUsecase;
  final StoreLabelUsecase _storeLabelsUsecase;
  final TrashLabelUsecase _trashLabelUsecase;

  LabelsFacade({
    required this._fetchLabelByReferenceUsecase,
    required this._fetchAllLabelsUsecase,
    required this._storeLabelsUsecase,
    required this._trashLabelUsecase,
  });

  Future<List<Label>> fetchByReference(String reference) async {
    final result = await _fetchLabelByReferenceUsecase.execute(reference);
    // Best-effort enrichment: a lookup failure is already logged at the
    // use-case boundary, so degrade to no labels rather than abort the caller.
    return result.fold(
      (labels) => labels
          .map((label) => LabelMapper.applicationLabelToLabel(label))
          .toList(),
      (_) => const <Label>[],
    );
  }

  Future<List<Label>> fetchAll() async {
    final result = await _fetchAllLabelsUsecase.execute();
    return result.fold(
      (labels) => labels
          .map((label) => LabelMapper.applicationLabelToLabel(label))
          .toList(),
      (_) => const <Label>[],
    );
  }

  /// Distinct user-defined label strings used to feed the suggestion chips
  /// in the label entry bottom sheet.
  ///
  /// Pass [type] to scope the suggestions — e.g. callers on the receive
  /// flow (where the chosen string becomes a counterparty-visible BIP21
  /// `message=`) must restrict to [LabelType.address] so private
  /// transaction labels don't leak into outgoing messages.
  Future<Set<String>> fetchDistinctLabels({LabelType? type}) async {
    final labels = await fetchAll();
    return labels
        .where((l) => type == null || l.type == type)
        .map((l) => l.label)
        .toSet();
  }

  Future<Result<Label, LabelFailure>> store(NewLabel label) async {
    final result = await _storeLabelsUsecase.execute(
      NewApplicationLabel(
        type: label.type,
        label: label.label,
        reference: label.reference,
        origin: label.origin,
      ),
    );
    return result.map((stored) => LabelMapper.applicationLabelToLabel(stored));
  }

  Future<Result<Null, LabelFailure>> trash(int id) =>
      _trashLabelUsecase.execute(id);
}
