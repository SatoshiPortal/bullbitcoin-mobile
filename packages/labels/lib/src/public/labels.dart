import 'package:drift/drift.dart';
import 'package:labels/src/data/bip329_codec.dart';
import 'package:labels/src/data/drift_labels_repository.dart';
import 'package:labels/src/data/labels_converter_adapter.dart';
import 'package:labels/src/data/wallet_freeze_adapter.dart';
import 'package:labels/src/domain/application_label.dart';
import 'package:labels/src/domain/formatted_labels.dart';
import 'package:labels/src/domain/label_failure.dart';
import 'package:labels/src/domain/label_format.dart';
import 'package:labels/src/domain/labels_converter_port.dart';
import 'package:labels/src/domain/labels_converter_port_registry.dart';
import 'package:labels/src/domain/primitive/label_type.dart';
import 'package:labels/src/domain/store_label_application.dart';
import 'package:labels/src/domain/usecases/export_labels_usecase.dart';
import 'package:labels/src/domain/usecases/fetch_labels_usecase.dart';
import 'package:labels/src/domain/usecases/import_labels_usecase.dart';
import 'package:labels/src/domain/usecases/store_labels_usecase.dart';
import 'package:labels/src/domain/usecases/trash_label_usecase.dart';
import 'package:labels/src/public/label.dart';
import 'package:labels/src/public/new_label.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Label persistence and BIP-329 import and export.
class Labels {
  final FetchLabelsUsecase _fetchLabels;
  final StoreLabelUsecase _storeLabelsUsecase;
  final TrashLabelUsecase _trashLabelUsecase;

  final ExportLabelsUsecase _export;
  final ImportLabelsUsecase _importLabels;
  final LabelsConverterPort _converter;

  Labels._({
    required this._fetchLabels,
    required this._storeLabelsUsecase,
    required this._trashLabelUsecase,
    required this._export,
    required this._importLabels,
    required this._converter,
  });

  factory Labels.open({
    required GeneratedDatabase database,
    required Future<Sync> Function() sync,
    required Future<Wallet> Function(String) openWallet,
  }) {
    final repository = DriftLabelsRepository(database: database);
    final converter = LabelsConverterAdapter(Bip329LabelsCodec());
    final freezes = WalletFreezeAdapter(sync: sync, openWallet: openWallet);
    return Labels._(
      fetchLabels: FetchLabelsUsecase(repository),
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
    );
  }

  int maxImportBytes(LabelFormat format) => _converter.maxImportBytes(format);

  Future<Result<String, LabelFailure>> exportLabels(LabelFormat format) =>
      _export.call(format);

  Future<Result<int, LabelFailure>> importLabels(
    String content,
    LabelFormat format,
  ) => _importLabels.call(switch (format) {
    LabelFormat.bip329 => FormattedLabelsBIP329(jsonl: content),
  });

  /// Lists all labels or those matching [reference]. An empty match is a
  /// successful read.
  Future<Result<List<Label>, LabelFailure>> fetch({String? reference}) async {
    final result = await _fetchLabels.execute(reference: reference);
    return result.map((labels) => labels.map(_toLabel).toList());
  }

  /// Distinct label strings. Receive callers must pass [LabelType.address]
  /// because BIP-21 messages are visible to the payer.
  Future<Result<Set<String>, LabelFailure>> suggestions({
    LabelType? type,
  }) async {
    final result = await fetch();
    return result.map(
      (labels) => labels
          .where((label) => type == null || label.type == type)
          .map((label) => label.label)
          .toSet(),
    );
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

  Future<Result<void, LabelFailure>> trash(int id) =>
      _trashLabelUsecase.execute(id);
}

Label _toLabel(ApplicationLabel label) => Label(
  id: label.id,
  type: label.type,
  label: label.label,
  reference: label.reference,
  origin: label.origin,
);
