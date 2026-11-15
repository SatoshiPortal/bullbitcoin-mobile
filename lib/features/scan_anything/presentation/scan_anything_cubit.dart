import 'package:bb_mobile/features/scan_anything/domain/bbqr_assembler.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/decode_bbqr_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_history.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/identify_scanned_content_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/import_scanned_labels_usecase.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class ScanAnythingCubit extends Cubit<ScanAnythingState> {
  final IdentifyScannedContentUsecase _identifyScannedContentUsecase;
  final DecodeBbqrUsecase _decodeBbqrUsecase;
  final ImportScannedLabelsUsecase _importScannedLabelsUsecase;
  final Future<String?> Function(String path) _decodeImage;
  final ScanHistory _history;
  final DateTime Function() _now;
  final BbqrAssembler _bbqr = BbqrAssembler();

  ScanAnythingCubit({
    required this._identifyScannedContentUsecase,
    required this._decodeBbqrUsecase,
    required this._importScannedLabelsUsecase,
    required this._decodeImage,
    required this._history,
    this._now = DateTime.now,
  }) : super(ScanAnythingState(history: _history.entries));

  bool get _isBusy => state.isIdentifying || state.content != null;

  Future<void> onScanned(String payload) async {
    if (_isBusy) return;
    if (!BbqrAssembler.isPart(payload)) {
      _bbqr.reset();
      await _identify(payload);
      return;
    }

    final progress = _bbqr.add(payload);
    final parts = progress.completeParts;
    if (parts == null) {
      emit(
        state.withMultipartProgress(
          received: progress.received,
          total: progress.total,
        ),
      );
      return;
    }

    emit(state.identifying());
    final decoded = await _decodeBbqrUsecase.execute(
      parts: parts,
      type: progress.type,
    );
    if (isClosed) return;
    switch (decoded) {
      case Ok(:final value):
        await _identify(value);
      case Err(:final failure):
        emit(state.withFailure(failure));
    }
  }

  void updateInput(String input) {
    if (_isBusy) return;
    emit(state.withInput(input));
  }

  Future<void> identify() async {
    if (_isBusy) return;
    await _identify(state.rawInput);
  }

  Future<void> importLabels() async {
    final content = state.content;
    if (content is! LabelsExportContent || state.isImportingLabels) return;
    if (state.importedLabelCount != null) return;
    emit(state.importingLabels());
    final result = await _importScannedLabelsUsecase.execute(content.jsonl);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => state.withImportedLabels(value),
      Err(:final failure) => state.withActionFailure(failure),
    });
  }

  Future<void> onImagePicked(String path) async {
    if (_isBusy) return;
    emit(state.identifying());
    final text = await _decodeImage(path);
    if (isClosed) return;
    if (text == null) {
      emit(state.withFailure(const ScanAnythingUnrecognizedFailure()));
      return;
    }
    emit(state.withInput(state.rawInput));
    await onScanned(text);
  }

  void openHistoryEntry(ScanHistoryEntry entry) {
    if (_isBusy) return;
    emit(state.withContent(entry.content));
  }

  void clearHistory() {
    _history.clear();
    emit(state.withHistory(_history.entries));
  }

  void reset() {
    _bbqr.reset();
    emit(ScanAnythingState(history: _history.entries));
  }

  Future<void> _identify(String input) async {
    emit(state.identifying());
    final result = await _identifyScannedContentUsecase.execute(input);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _history.add(value, time: _now());
        emit(state.withContent(value).withHistory(_history.entries));
      case Err(:final failure):
        emit(state.withFailure(failure));
    }
  }
}
