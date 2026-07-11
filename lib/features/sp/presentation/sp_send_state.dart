import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_send_state.freezed.dart';

@freezed
sealed class SpSendState with _$SpSendState {
  const factory SpSendState({
    SpFailure? error,
    @Default(false) bool isLoading,
    // Re-entrancy guard for the sign+broadcast path. Dedicated flag (not
    // isLoading) so the irreversible finalize -> sign -> broadcast sequence
    // runs once: a second concurrent invocation would produce a second signed
    // tx spending the same coins.
    @Default(false) bool isBroadcasting,
    SpRecipient? recipient,
    BigInt? amountSat,
    @Default(false) bool isMax,
    @Default(SpConfig.defaultFeerateSatPerVb) int feerate,
    SpTxDraft? txSimulation,
    @Default('') String txid,
  }) = _SpSendState;
  const SpSendState._();

  bool get hasSendRecipient => recipient != null;
  bool get hasTxSimulation => txSimulation != null;
  bool get sendSuccess => txid.isNotEmpty;
}
