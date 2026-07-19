import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'joinstr_state.freezed.dart';

enum JoinstrStatus { idle, loadingPools, error }

@freezed
abstract class JoinstrState with _$JoinstrState {
  const factory JoinstrState({
    @Default(JoinstrStatus.idle) JoinstrStatus status,
    @Default([]) List<JoinstrPool> pools,
    Wallet? wallet,

    /// Rounds this device initiated or joined, newest first. A waiting round
    /// blocks new interactions; completed and failed ones stay visible on the
    /// My Pools tab for the session.
    @Default([]) List<JoinstrRound> rounds,

    /// Completed coinjoins, persisted across restarts.
    @Default([]) List<JoinstrHistoryEntry> history,
    @Default('') String relay,
    JoinstrException? error,
    @Default('0.001') String denominationBtc,
    @Default('2') String peers,
    @Default('1') String feeRate,
  }) = _JoinstrState;

  const JoinstrState._();

  /// A coinjoin round blocks in the bindings until it broadcasts or the pool
  /// times out, so every other action is disabled while one is in flight.
  bool get isRunning => rounds.any((r) => r.isWaiting);

  bool get canInteract => !isRunning && wallet != null;
}
