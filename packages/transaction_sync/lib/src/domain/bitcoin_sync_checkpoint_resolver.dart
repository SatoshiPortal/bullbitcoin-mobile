import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'bitcoin_sync_checkpoint.dart';
import 'bitcoin_sync_script_type.dart';
import 'mainnet_bitcoin_sync_checkpoints.dart';
import 'wallet_transaction_sync_failure.dart';

/// Offline birthday policy over a fixed, independently verified catalogue.
final class BitcoinSyncCheckpointResolver {
  static const safetyMargin = Duration(days: 7);

  /// [now] is explicit so the same inputs always produce the same result.
  ///
  /// Uses the beginning of the birthday's UTC day, then steps back at least a
  /// week. Each monthly checkpoint strictly precedes its cutoff. Block header
  /// timestamps are not a proof of real wall-clock mining time.
  ///
  /// Unknown or pre-activation mainnet dates use the output script's floor,
  /// including when that floor cannot satisfy the birthday margin. This is
  /// the supported-history policy, never an inferred recent birthday.
  @useResult
  static Result<BitcoinSyncCheckpoint, WalletTransactionSyncFailure> resolve({
    required BitcoinNetwork network,
    DateTime? birthday,
    BitcoinSyncScriptType scriptType = BitcoinSyncScriptType.segwitV0,
    required DateTime now,
  }) {
    final storedBirthday = birthday?.toUtc();
    final utcBirthday =
        storedBirthday != null && storedBirthday.isAfter(now.toUtc())
        ? now.toUtc()
        : storedBirthday;
    if (!network.isMainnet) {
      return Ok(BitcoinSyncCheckpoint.genesis(network));
    }
    final floor = scriptType.floor;
    if (utcBirthday == null) return Ok(floor);
    if (utcBirthday.millisecondsSinceEpoch <
        scriptType.earliestDate.millisecondsSinceEpoch) {
      return Ok(floor);
    }

    final cutoff = DateTime.utc(
      utcBirthday.year,
      utcBirthday.month,
      utcBirthday.day,
    ).subtract(safetyMargin);
    final cutoffSeconds = cutoff.millisecondsSinceEpoch ~/ 1000;
    var checkpoint = floor;
    for (final entry in mainnetBitcoinSyncCheckpoints) {
      if (entry.cutoffTimestamp > cutoffSeconds) break;
      if (entry.height <= floor.height) continue;
      checkpoint = BitcoinSyncCheckpoint(
        height: entry.height,
        blockHash: entry.blockHash,
        blockTimestamp: entry.blockTimestamp,
      );
    }
    return Ok(checkpoint);
  }
}
