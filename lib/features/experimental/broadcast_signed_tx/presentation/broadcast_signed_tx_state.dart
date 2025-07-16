import 'package:bb_mobile/core/bbqr/bbqr_service.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'broadcast_signed_tx_state.freezed.dart';

@freezed
abstract class BroadcastSignedTxState with _$BroadcastSignedTxState {
  const factory BroadcastSignedTxState({
    required BbqrService bbqr,
    @Default(null) ParsedTx? transaction,
    @Default(false) bool isBroadcasted,
    @Default(null) Uri? pushTxUri,
    String? error,
  }) = _BroadcastSignedTxState;
}
