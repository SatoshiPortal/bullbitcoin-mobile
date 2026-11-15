import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_history.dart';

final class ScanAnythingState {
  final String rawInput;
  final bool isIdentifying;
  final ScannedContent? content;
  final ScanAnythingFailure? failure;
  final int? multipartReceived;
  final int? multipartTotal;
  final bool isImportingLabels;
  final int? importedLabelCount;
  final List<ScanHistoryEntry> history;

  const ScanAnythingState({
    this.rawInput = '',
    this.isIdentifying = false,
    this.content,
    this.failure,
    this.multipartReceived,
    this.multipartTotal,
    this.isImportingLabels = false,
    this.importedLabelCount,
    this.history = const [],
  });

  bool get hasMultipartProgress =>
      multipartReceived != null && multipartTotal != null;

  ScanAnythingState withInput(String rawInput) =>
      ScanAnythingState(rawInput: rawInput, history: history);

  ScanAnythingState identifying() => ScanAnythingState(
    rawInput: rawInput,
    isIdentifying: true,
    history: history,
  );

  ScanAnythingState withMultipartProgress({
    required int received,
    required int total,
  }) => ScanAnythingState(
    history: history,
    rawInput: rawInput,
    multipartReceived: received,
    multipartTotal: total,
  );

  ScanAnythingState withContent(ScannedContent content) => ScanAnythingState(
    history: history,
    rawInput: content.copyText == null ? '' : rawInput,
    content: content,
  );

  ScanAnythingState importingLabels() => ScanAnythingState(
    history: history,
    rawInput: rawInput,
    content: content,
    isImportingLabels: true,
  );

  ScanAnythingState withImportedLabels(int count) => ScanAnythingState(
    history: history,
    rawInput: rawInput,
    content: content,
    importedLabelCount: count,
  );

  ScanAnythingState withActionFailure(ScanAnythingFailure failure) =>
      ScanAnythingState(
        rawInput: rawInput,
        content: content,
        failure: failure,
        history: history,
      );

  ScanAnythingState withFailure(ScanAnythingFailure failure) =>
      ScanAnythingState(rawInput: rawInput, failure: failure, history: history);

  ScanAnythingState withHistory(List<ScanHistoryEntry> history) =>
      ScanAnythingState(
        rawInput: rawInput,
        isIdentifying: isIdentifying,
        content: content,
        failure: failure,
        multipartReceived: multipartReceived,
        multipartTotal: multipartTotal,
        isImportingLabels: isImportingLabels,
        importedLabelCount: importedLabelCount,
        history: history,
      );
}
