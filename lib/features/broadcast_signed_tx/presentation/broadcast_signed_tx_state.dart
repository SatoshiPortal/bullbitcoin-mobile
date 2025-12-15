import 'package:bb_mobile/core_deprecated/bbqr/bbqr.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'broadcast_signed_tx_state.freezed.dart';

@freezed
abstract class BroadcastSignedTxState with _$BroadcastSignedTxState {
  const factory BroadcastSignedTxState({
    required Bbqr bbqr,
    @Default(null) ParsedTx? transaction,
    @Default(null) String? unsignedPsbt,
    @Default(false) bool isBroadcasted,
    @Default(null) Uri? pushTxUri,
    @Default(null) Exception? error,
  }) = _BroadcastSignedTxState;
}
