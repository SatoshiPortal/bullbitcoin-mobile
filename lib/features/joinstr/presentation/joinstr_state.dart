import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
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

    /// The wallet's spendable coins, for the input picker.
    @Default([]) List<JoinstrCoin> coins,
    @Default(false) bool loadingCoins,

    /// Coin the user picked for a pool they are about to create.
    JoinstrCoin? selectedCoin,

    /// Rounds this device initiated or joined, newest first. Several can be in
    /// flight at once; completed and failed ones stay visible on My Pools.
    @Default([]) List<JoinstrRound> rounds,

    /// Completed coinjoins, persisted across restarts.
    @Default([]) List<JoinstrHistoryEntry> history,
    @Default('') String relay,
    JoinstrException? error,
    @Default('2') String peers,
    @Default('1') String feeRate,
  }) = _JoinstrState;

  const JoinstrState._();

  /// True while at least one coinjoin is waiting. It no longer blocks the UI:
  /// several pools can run at once, each on its own input coin.
  bool get isRunning => rounds.any((r) => r.isWaiting);

  bool get canInteract => wallet != null;

  /// Outpoints already committed to an in-flight pool, so they are not offered
  /// again for another one.
  Set<String> get busyOutpoints => {
    for (final r in rounds)
      if (r.isWaiting) r.inputOutpoint,
  };

  /// Coins that can fund a pool of [denominationSat]: value inside the required
  /// window and not already used by a waiting pool. Used when joining, where
  /// the denomination is fixed by the pool.
  List<JoinstrCoin> eligibleCoins(int denominationSat) => [
    for (final c in coins)
      if (Joinstr.isEligibleCoin(
            valueSat: c.valueSat,
            denominationSat: denominationSat,
          ) &&
          !busyOutpoints.contains(c.outpoint))
        c,
  ];

  /// Coins selectable when creating a pool: not already committed to another
  /// in-flight pool and large enough to leave a positive denomination. The
  /// denomination is then derived from whichever coin the user picks.
  List<JoinstrCoin> get createCoins => [
    for (final c in coins)
      if (!busyOutpoints.contains(c.outpoint) &&
          c.valueSat > Joinstr.minInputSurplusSat)
        c,
  ];
}
