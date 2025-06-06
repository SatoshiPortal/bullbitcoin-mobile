import 'package:bb_mobile/core/bbqr/bbqr_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_signed_tx_state.freezed.dart';

@freezed
abstract class ScanSignedTxState with _$ScanSignedTxState {
  const factory ScanSignedTxState({
    @Default(null) ({TxFormat format, String data})? transaction,
    @Default('') String txid,
    @Default({}) Map<int, String> parts,
    String? error,
  }) = _ScanSignedTxState;

  factory ScanSignedTxState.initial() => const ScanSignedTxState();
}
