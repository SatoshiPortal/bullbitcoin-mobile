import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// A rough projection from one measured SegWit recovery, not a benchmark for
/// other scripts. Match rates, hardware, peers and later chain growth vary.
final class BitcoinRecoveryEstimate {
  static const measuredTip = 973604;
  static const measuredSeconds = 2965;
  static const measuredGigabytes = 11.7;
  static const measuredBlocks = measuredTip - 481823;

  final BitcoinSyncScriptType scriptType;

  const BitcoinRecoveryEstimate(this.scriptType);

  int get blocks => measuredTip - scriptType.floor.height;
  int get minutes =>
      (measuredSeconds * blocks / measuredBlocks / 60 / 5).ceil() * 5;
  int get gigabytes => (measuredGigabytes * blocks / measuredBlocks).ceil();

  static DateTime? startDate({
    required BitcoinNetwork network,
    required BitcoinSyncScriptType scriptType,
    required BitcoinSyncCheckpoint checkpoint,
  }) => network.isMainnet && checkpoint == scriptType.floor
      ? scriptType.earliestDate
      : checkpoint.timestamp;

  static int monthsFrom(DateTime start, DateTime now) {
    final months = (now.year - start.year) * 12 + now.month - start.month;
    return months < 0 ? 0 : months;
  }
}
