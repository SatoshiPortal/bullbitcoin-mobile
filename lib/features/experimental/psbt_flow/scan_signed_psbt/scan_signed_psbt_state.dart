import 'package:bb_mobile/core/bbqr/bbqr_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_signed_psbt_state.freezed.dart';

@freezed
abstract class ScanSignedPsbtState with _$ScanSignedPsbtState {
  const factory ScanSignedPsbtState({
    @Default(null) ({TxFormat format, String data})? transaction,
    @Default('') String txid,
    @Default({}) Map<int, String> parts,
    String? error,
  }) = _ScanSignedPsbtState;

  factory ScanSignedPsbtState.initial() => const ScanSignedPsbtState();
}
