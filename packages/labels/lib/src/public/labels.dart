import 'dart:io';

import 'package:meta/meta.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:secrets/secrets.dart';

import '../data/labels_import.dart';
import '../data/labels_store.dart';
import '../data/frozen_utxos_freeze_store.dart';
import '../data/reserved_address_port_impl.dart';

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
  final LabelsStore? _store;
  final FreezeStorePort _freezes;
  final ReservedAddressPort _reservedAddresses;
  final FetchLabelsUsecase _fetchLabels;
  final StoreLabelUsecase _storeLabelsUsecase;
  final TrashLabelUsecase _trashLabelUsecase;

  final ExportLabelsUsecase _export;
  final ImportLabelsUsecase _importLabels;
  final LabelsConverterPort _converter;

  Labels._({
    required this._freezes,
    required this._reservedAddresses,
    this._store,
    required this._fetchLabels,
    required this._storeLabelsUsecase,
    required this._trashLabelUsecase,
    required this._export,
    required this._importLabels,
    required this._converter,
  });

  @useResult
  static Future<Result<Labels, LabelFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required Future<Sync> Function() sync,
    required Future<Wallet> Function(String) openWallet,
  }) async {
    try {
      final opened = await LabelsStore.open(file, admission, existing: true);
      if (opened case Err(:final failure)) {
        return Err(
          failure is DatabaseNotReady ||
                  failure is DatabaseKeyUnavailable &&
                      failure.reason == DatabaseKeyProblem.locked
              ? const LabelsStorageNotReadyFailure()
              : const LabelUnexpectedFailure(),
        );
      }
      final store = (opened as Ok<LabelsStore, DatabaseOpenFailure>).value;
      var published = false;
      try {
        final readiness = await readLabelsReadiness(store.database);
        if (readiness case Ok(value: final ready)
            when ready != OwnerReadiness.pending) {
          final owner = _usingDatabase(
            database: store.database,
            sync: sync,
            openWallet: openWallet,
            store: store,
          );
          published = true;
          return Ok(owner);
        }
        if (readiness case Ok(value: OwnerReadiness.pending)) {
          return const Err(LabelsStorageNotReadyFailure());
        }
        return const Err(LabelUnexpectedFailure());
      } finally {
        if (!published) await store.handle.close();
      }
    } on Exception {
      return const Err(LabelUnexpectedFailure());
    }
  }

  @useResult
  Future<Result<void, LabelFailure>> close() async {
    try {
      await _store?.handle.close();
      return const Ok(null);
    } on Exception {
      return const Err(LabelUnexpectedFailure());
    }
  }

  static Labels _usingDatabase({
    LabelsStore? store,
    required GeneratedDatabase database,
    required Future<Sync> Function() sync,
    required Future<Wallet> Function(String) openWallet,
  }) {
    final repository = DriftLabelsRepository(database: database);
    final converter = LabelsConverterAdapter(Bip329LabelsCodec());
    final freezes = WalletFreezeAdapter(sync: sync, openWallet: openWallet);
    return Labels._(
      store: store,
      freezes: FrozenUtxosFreezeStore(database: database),
      reservedAddresses: ReservedAddressPortImpl(repository),
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

/// Owner-built ports, exposed only through the composition entry library.
extension LabelsSetup on Labels {
  FreezeStorePort get freezes => _freezes;
  ReservedAddressPort get reservedAddresses => _reservedAddresses;
}

@visibleForTesting
Labels createLabelsForTesting({
  required GeneratedDatabase database,
  required Future<Sync> Function() sync,
  required Future<Wallet> Function(String) openWallet,
}) => Labels._usingDatabase(
  database: database,
  sync: sync,
  openWallet: openWallet,
);
