import 'package:bb_mobile/features/sp/data/mappers/sp_balance_mapper.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpBalanceMapper.toDomain', () {
    test('wraps both amounts in Sats', () {
      final balance = SpBalanceMapper.toDomain(
        bwk.SpBalanceView(
          confirmedSat: BigInt.from(1000),
          totalUnifiedSat: BigInt.from(2500),
          lastScannedHeight: 800000,
        ),
      );

      expect(balance.confirmedSat, Sats.fromInt(1000));
      expect(balance.totalUnifiedSat, Sats.fromInt(2500));
    });

    test('maps an empty balance', () {
      final balance = SpBalanceMapper.toDomain(
        bwk.SpBalanceView(
          confirmedSat: BigInt.zero,
          totalUnifiedSat: BigInt.zero,
        ),
      );

      expect(balance.confirmedSat, Sats.zero);
      expect(balance.totalUnifiedSat, Sats.zero);
    });

    test('maps a unified total below the confirmed part unchanged', () {
      // bwk clamps the unified total to zero on a negative running total while
      // the confirmed sum stays positive, so the two can disagree. Failing here
      // would fail the session snapshot that builds the balance.
      final balance = SpBalanceMapper.toDomain(
        bwk.SpBalanceView(
          confirmedSat: BigInt.from(2000),
          totalUnifiedSat: BigInt.from(1000),
        ),
      );

      expect(balance.confirmedSat, Sats.fromInt(2000));
      expect(balance.totalUnifiedSat, Sats.fromInt(1000));
    });
  });
}
