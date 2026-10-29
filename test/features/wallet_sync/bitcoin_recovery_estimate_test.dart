import 'package:bb_mobile/features/wallet_sync/domain/bitcoin_recovery_estimate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test('unmeasured script costs scale measured block counts and round up', () {
    const taproot = BitcoinRecoveryEstimate(BitcoinSyncScriptType.taproot);
    const legacy = BitcoinRecoveryEstimate(BitcoinSyncScriptType.preSegwit);
    expect(taproot.blocks, 263973);
    expect(taproot.minutes, 30);
    expect(taproot.gigabytes, 7);
    expect(legacy.blocks, 808824);
    expect(legacy.minutes, 85);
    expect(legacy.gigabytes, 20);
  });
  test(
    'month counts reflect effective scan start without fabricated padding',
    () {
      final now = DateTime.utc(2026, 10, 28);
      expect(
        BitcoinRecoveryEstimate.monthsFrom(DateTime.utc(2021, 11), now),
        59,
      );
      expect(
        BitcoinRecoveryEstimate.monthsFrom(DateTime.utc(2017, 8), now),
        110,
      );
      expect(
        BitcoinRecoveryEstimate.monthsFrom(DateTime.utc(2012, 2), now),
        176,
      );
      expect(BitcoinRecoveryEstimate.monthsFrom(DateTime.utc(2027), now), 0);
    },
  );
}
