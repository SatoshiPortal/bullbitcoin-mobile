import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:drift/drift.dart';
import 'package:labels/src/data/bip329_codec.dart';
import 'package:labels/src/data/drift_labels_repository.dart';
import 'package:labels/src/data/labels_converter_adapter.dart';
import 'package:labels/src/data/payjoin_labels_adapter.dart';
import 'package:labels/src/data/reserved_address_port_impl.dart';
import 'package:labels/src/data/wallet_freeze_adapter.dart';
import 'package:labels/src/domain/application_label.dart';
import 'package:labels/src/domain/formatted_labels.dart';
import 'package:labels/src/domain/label_failure.dart';
import 'package:labels/src/domain/label_format.dart';
import 'package:labels/src/domain/labels_converter_port.dart';
import 'package:labels/src/domain/labels_converter_port_registry.dart';
import 'package:labels/src/domain/labels_repository_port.dart';
import 'package:labels/src/domain/primitive/label_type.dart';
import 'package:labels/src/domain/store_label_application.dart';
import 'package:labels/src/domain/usecases/export_labels_usecase.dart';
import 'package:labels/src/domain/usecases/fetch_all_labels_usecase.dart';
import 'package:labels/src/domain/usecases/fetch_label_by_reference_usecase.dart';
import 'package:labels/src/domain/usecases/import_labels_usecase.dart';
import 'package:labels/src/domain/usecases/store_labels_usecase.dart';
import 'package:labels/src/domain/usecases/trash_label_usecase.dart';
import 'package:labels/src/public/label.dart';
import 'package:labels/src/public/new_label.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

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

  final ExportLabelsUsecase _export;
  final ImportLabelsUsecase _importLabels;
  final LabelsConverterPort _converter;
  final LabelsRepositoryPort _repository;

  LabelsFacade._({
    required this._fetchLabelByReferenceUsecase,
    required this._fetchAllLabelsUsecase,
    required this._storeLabelsUsecase,
    required this._trashLabelUsecase,
    required this._export,
    required this._importLabels,
    required this._converter,
    required this._repository,
  });

  factory LabelsFacade.open({
    required GeneratedDatabase database,
    required Future<Sync> Function() sync,
    required Future<Wallet> Function(String) openWallet,
  }) {
    final repository = DriftLabelsRepository(database: database);
    final converter = LabelsConverterAdapter(Bip329LabelsCodec());
    final freezes = WalletFreezeAdapter(sync: sync, openWallet: openWallet);
    return LabelsFacade._(
      fetchLabelByReferenceUsecase: FetchLabelByReferenceUsecase(
        labelRepository: repository,
      ),
      fetchAllLabelsUsecase: FetchAllLabelsUsecase(labelRepository: repository),
      storeLabelsUsecase: StoreLabelUsecase(labelRepository: repository),
      trashLabelUsecase: TrashLabelUsecase(labelRepository: repository),
      export: ExportLabelsUsecase(
        labelRepository: repository,
        converterRegistry: LabelsConverterPortRegistry({
          LabelFormat.bip329: converter,
        }),
        walletFreeze: freezes,
      ),
      importLabels: ImportLabelsUsecase(
        labelRepository: repository,
        labelConverter: converter,
        walletFreeze: freezes,
      ),
      converter: converter,
      repository: repository,
    );
  }

  ReservedAddressPort reservedAddresses() =>
      ReservedAddressPortImpl(_repository);

  int maxImportBytes(LabelFormat format) => _converter.maxImportBytes(format);

  Future<Result<String, LabelFailure>> exportLabels(LabelFormat format) =>
      _export.call(format);

  Future<Result<int, LabelFailure>> importLabels(
    String content,
    LabelFormat format,
  ) => _importLabels.call(switch (format) {
    LabelFormat.bip329 => FormattedLabelsBIP329(jsonl: content),
  });

  PayjoinLabelsPort payjoinLabels() => AppPayjoinLabelsAdapter((label) async {
    await store(label);
  });

  Future<List<Label>> fetchByReference(String reference) async {
    final result = await _fetchLabelByReferenceUsecase.execute(reference);
    // Best-effort enrichment: a lookup failure is already logged at the
    // use-case boundary, so degrade to no labels rather than abort the caller.
    return result.fold(
      (labels) => labels.map((label) => _toLabel(label)).toList(),
      (_) => const <Label>[],
    );
  }

  Future<List<Label>> fetchAll() async {
    final result = await fetchAllOrFailure();
    return result.fold((labels) => labels, (_) => const <Label>[]);
  }

  /// [fetchAll] without the best-effort degradation, for the caller that must
  /// tell "there are no labels" apart from "the read failed" — reporting the
  /// former for the latter would look like the labels had been deleted.
  Future<Result<List<Label>, LabelFailure>> fetchAllOrFailure() async {
    final result = await _fetchAllLabelsUsecase.execute();
    return result.map(
      (labels) => labels.map((label) => _toLabel(label)).toList(),
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
    return result.map((stored) => _toLabel(stored));
  }

  Future<Result<Null, LabelFailure>> trash(int id) =>
      _trashLabelUsecase.execute(id);
}

Label _toLabel(ApplicationLabel label) => Label(
  id: label.id,
  type: label.type,
  label: label.label,
  reference: label.reference,
  origin: label.origin,
);
