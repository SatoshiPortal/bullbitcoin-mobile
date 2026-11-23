import 'package:satoshifier/bbqr.dart';
import 'package:send/src/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:send/src/broadcast_signed_tx/type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'broadcast_signed_tx_state.freezed.dart';

@freezed
abstract class BroadcastSignedTxState with _$BroadcastSignedTxState {
  const factory BroadcastSignedTxState({
    required Bbqr bbqr,
    @Default(null) ParsedTx? transaction,
    @Default(null) String? unsignedPsbt,
    @Default(false) bool isBroadcasting,
    @Default(false) bool isBroadcasted,
    @Default(null) Uri? pushTxUri,
    @Default(null) BroadcastSignedTxFailure? failure,
  }) = _BroadcastSignedTxState;
}
