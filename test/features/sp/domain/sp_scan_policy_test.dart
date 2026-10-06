import 'package:bb_mobile/features/sp/domain/sp_scan_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tip = 900000;

  SpScanTrigger triggerAt(int? lastScannedHeight, {int? chainTip = tip}) =>
      SpScanPolicy(
        lastScannedHeight: lastScannedHeight,
        chainTip: chainTip,
      ).trigger;

  group('spAutoScanMaxBlocksBehind', () {
    test('is a month of blocks at mainnet pace', () {
      expect(spAutoScanMaxBlocksBehind, 4320);
    });
  });

  group('SpScanPolicy.trigger with auto scanning off', () {
    SpScanTrigger offAt(int? lastScannedHeight) => SpScanPolicy(
      lastScannedHeight: lastScannedHeight,
      chainTip: tip,
      isAutoScanEnabled: false,
    ).trigger;

    test('a wallet at the tip is manual only', () {
      expect(offAt(tip), SpScanTrigger.manualOnly);
    });

    test('a wallet slightly behind is manual only, never automatic', () {
      expect(offAt(tip - 1), SpScanTrigger.manualOnly);
    });

    test('a wallet far behind is manual only, never nudged', () {
      // The user chose to drive scanning, so they are not asked to start one.
      expect(
        offAt(tip - spAutoScanMaxBlocksBehind - 1),
        SpScanTrigger.manualOnly,
      );
    });
  });

  group('SpScanPolicy.trigger', () {
    test('unset cursor is manual only', () {
      expect(triggerAt(null), SpScanTrigger.manualOnly);
    });

    test('unknown tip is manual only', () {
      expect(triggerAt(tip, chainTip: null), SpScanTrigger.manualOnly);
    });

    test('unset cursor and unknown tip is manual only', () {
      expect(triggerAt(null, chainTip: null), SpScanTrigger.manualOnly);
    });

    test('a cursor at the tip is up to date', () {
      expect(triggerAt(tip), SpScanTrigger.upToDate);
    });

    test('one block behind is automatic', () {
      expect(triggerAt(tip - 1), SpScanTrigger.automatic);
    });

    test('exactly at the threshold is automatic', () {
      expect(
        triggerAt(tip - spAutoScanMaxBlocksBehind),
        SpScanTrigger.automatic,
      );
    });

    test('one block over the threshold needs confirmation', () {
      expect(
        triggerAt(tip - spAutoScanMaxBlocksBehind - 1),
        SpScanTrigger.needsConfirmation,
      );
    });

    test('far behind needs confirmation', () {
      expect(triggerAt(709632), SpScanTrigger.needsConfirmation);
    });

    test('a cursor ahead of the tip is up to date, so nothing rescans', () {
      expect(triggerAt(tip + 10), SpScanTrigger.upToDate);
    });
  });

  group('SpScanPolicy.needsUser', () {
    bool needsUser(
      int? lastScannedHeight, {
      int? chainTip = tip,
      bool isAutoScanEnabled = true,
    }) => SpScanPolicy(
      lastScannedHeight: lastScannedHeight,
      chainTip: chainTip,
      isAutoScanEnabled: isAutoScanEnabled,
    ).needsUser;

    test('a synced wallet is never nudged', () {
      expect(needsUser(tip), isFalse);
      expect(needsUser(tip, isAutoScanEnabled: false), isFalse);
    });

    test('slightly behind with auto scanning on is not nudged', () {
      // The sync tick will pick it up, so there is nothing to ask.
      expect(needsUser(tip - 2), isFalse);
    });

    test('slightly behind with auto scanning off is nudged', () {
      // Nothing will catch it up, however small the gap.
      expect(needsUser(tip - 1, isAutoScanEnabled: false), isTrue);
    });

    test('past the threshold is nudged even with auto scanning on', () {
      expect(needsUser(tip - spAutoScanMaxBlocksBehind - 1), isTrue);
    });

    test('no cursor or no tip cannot be judged, so is not nudged', () {
      expect(needsUser(null), isFalse);
      expect(needsUser(tip - 1, chainTip: null), isFalse);
      expect(needsUser(null, isAutoScanEnabled: false), isFalse);
    });

    test('a cursor ahead of the tip is treated as synced', () {
      expect(needsUser(tip + 5, isAutoScanEnabled: false), isFalse);
    });
  });
}
