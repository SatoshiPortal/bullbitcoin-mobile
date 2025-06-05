import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_signed_psbt_state.freezed.dart';

@freezed
abstract class ScanSignedPsbtState with _$ScanSignedPsbtState {
  const factory ScanSignedPsbtState({
    @Default('') String psbt,
    @Default('') String txid,
    @Default({}) Map<int, String> parts,
    String? error,
  }) = _ScanSignedPsbtState;

  factory ScanSignedPsbtState.initial() => const ScanSignedPsbtState();
}
