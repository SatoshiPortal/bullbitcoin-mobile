import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'joinstr_state.freezed.dart';

enum JoinstrStatus { idle, loadingPools, running, done, error }

@freezed
abstract class JoinstrState with _$JoinstrState {
  const factory JoinstrState({
    @Default(JoinstrStatus.idle) JoinstrStatus status,
    @Default([]) List<JoinstrPool> pools,
    Wallet? wallet,
    JoinstrPool? activePool,
    String? txId,
    JoinstrException? error,
    @Default('100000') String denominationSat,
    @Default('2') String peers,
    @Default('1') String feeRate,
  }) = _JoinstrState;

  const JoinstrState._();

  bool get isRunning => status == JoinstrStatus.running;

  /// A coinjoin round holds the isolate until it broadcasts or the pool times
  /// out, so every other action is disabled while one is in flight.
  bool get canInteract => !isRunning && wallet != null;
}
