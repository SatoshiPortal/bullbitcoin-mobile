import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
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
    @Default(null) int? fee,
    @Default([]) List<DecodedOutput> decodedOutputs,
  }) = _BroadcastSignedTxState;
}
