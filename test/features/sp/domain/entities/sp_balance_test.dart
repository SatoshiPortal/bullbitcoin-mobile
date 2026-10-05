import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpBalance', () {
    test('accepts a unified total above the confirmed part', () {
      final balance = SpBalance(
        confirmedSat: Sats.fromInt(1000),
        totalUnifiedSat: Sats.fromInt(1500),
      );

      expect(balance.confirmedSat, Sats.fromInt(1000));
      expect(balance.totalUnifiedSat, Sats.fromInt(1500));
    });

    test('accepts a unified total equal to the confirmed part', () {
      final balance = SpBalance(
        confirmedSat: Sats.fromInt(1000),
        totalUnifiedSat: Sats.fromInt(1000),
      );

      expect(balance.totalUnifiedSat, balance.confirmedSat);
    });

    test('accepts a zero balance', () {
      final balance = SpBalance(
        confirmedSat: Sats.zero,
        totalUnifiedSat: Sats.zero,
      );

      expect(balance.totalUnifiedSat, Sats.zero);
    });

    test('accepts a unified total below the confirmed part', () {
      // bwk computes the two figures differently and clamps the unified one to
      // zero on a negative running total, so they can disagree. Rejecting that
      // would fail the whole session snapshot over a balance anomaly.
      final balance = SpBalance(
        confirmedSat: Sats.fromInt(1000),
        totalUnifiedSat: Sats.fromInt(999),
      );

      expect(balance.confirmedSat, Sats.fromInt(1000));
      expect(balance.totalUnifiedSat, Sats.fromInt(999));
    });
  });
}
