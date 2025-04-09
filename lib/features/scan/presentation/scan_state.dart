import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_state.freezed.dart';

@freezed
class ScanState with _$ScanState {
  const factory ScanState({
    required bool isStreaming,
    required String data,
  }) = _ScanState;

  factory ScanState.initial() => const ScanState(isStreaming: false, data: '');
}
