import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/sp_scan_policy.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  const tip = 900000;

  SpState stateWith({
    int? lastScannedHeight = tip - 1,
    int? chainTip = tip,
    bool isAutoScanEnabled = false,
    bool isScanning = false,
  }) => SpState(
    lastScannedHeight: lastScannedHeight,
    chainTip: chainTip,
    isAutoScanEnabled: isAutoScanEnabled,
    isScanning: isScanning,
  );

  group('SpState.needsScanNudge', () {
    test('behind with auto scanning off asks the user', () {
      expect(stateWith().needsScanNudge, isTrue);
    });

    test('never while a scan is already running', () {
      // The nudge offers a scan, so it must not show when one cannot be started.
      expect(stateWith(isScanning: true).needsScanNudge, isFalse);
    });

    test('never when auto scanning will catch it up', () {
      expect(stateWith(isAutoScanEnabled: true).needsScanNudge, isFalse);
    });

    test(
      'still asks when auto scanning is on but the wallet drifted too far',
      () {
        expect(
          stateWith(
            lastScannedHeight: tip - spAutoScanMaxBlocksBehind - 1,
            isAutoScanEnabled: true,
          ).needsScanNudge,
          isTrue,
        );
      },
    );

    test('never when synced', () {
      expect(stateWith(lastScannedHeight: tip).needsScanNudge, isFalse);
    });

    test('never without a cursor or a tip to compare against', () {
      expect(stateWith(lastScannedHeight: null).needsScanNudge, isFalse);
      expect(stateWith(chainTip: null).needsScanNudge, isFalse);
    });
  });

  group('SpState.historyByDay', () {
    // Local time on purpose: the getter buckets by local calendar day, so the
    // fixtures are built from local DateTimes and the expected keys from local
    // midnight. Hardcoded epoch seconds would move across time zones.
    final may12 = DateTime(2024, 5, 12);
    final may13 = DateTime(2024, 5, 13);

    BigInt secondsAt(DateTime at) =>
        BigInt.from(at.millisecondsSinceEpoch ~/ 1000);

    SpPayment payment(
      String txid,
      DateTime? at, {
      SpPaymentStatus? status,
      int? height,
    }) => SpPayment(
      txid: txid,
      direction: SpPaymentDirection.receive,
      status:
          status ??
          (at == null ? SpPaymentStatus.unconfirmed : SpPaymentStatus.verified),
      amountSat: Sats.fromInt(1000),
      height: height,
      timestamp: at == null ? null : secondsAt(at),
    );

    final morning = payment('aa' * 32, DateTime(2024, 5, 12, 9));
    final evening = payment('bb' * 32, DateTime(2024, 5, 12, 17));
    final nextDay = payment('cc' * 32, DateTime(2024, 5, 13, 8));
    final pending = payment('dd' * 32, null);

    List<String> txidsOf(List<SpPayment>? payments) => [
      for (final item in payments ?? const <SpPayment>[]) item.txid,
    ];

    test('groups by local calendar day, newest day first', () {
      // Deliberately out of order: the getter owns the sorting.
      final grouped = SpState(
        history: [morning, nextDay, pending, evening],
      ).historyByDay;

      expect(grouped.keys.toList(), [
        spPendingGroupKey,
        may13.millisecondsSinceEpoch,
        may12.millisecondsSinceEpoch,
      ]);
    });

    test('orders a day newest payment first', () {
      final grouped = SpState(history: [morning, evening]).historyByDay;

      expect(txidsOf(grouped[may12.millisecondsSinceEpoch]), [
        'bb' * 32,
        'aa' * 32,
      ]);
    });

    test('an unconfirmed payment goes to the pending group', () {
      final grouped = SpState(history: [nextDay, pending]).historyByDay;

      expect(grouped.keys.first, spPendingGroupKey);
      expect(txidsOf(grouped[spPendingGroupKey]), ['dd' * 32]);
      expect(txidsOf(grouped[may13.millisecondsSinceEpoch]), ['cc' * 32]);
    });

    test('an unconfirmed payment with a time still goes to pending', () {
      final seen = payment(
        'ee' * 32,
        DateTime(2024, 5, 13, 9),
        status: SpPaymentStatus.unconfirmed,
      );

      final grouped = SpState(history: [nextDay, seen]).historyByDay;

      expect(txidsOf(grouped[spPendingGroupKey]), ['ee' * 32]);
      expect(txidsOf(grouped[may13.millisecondsSinceEpoch]), ['cc' * 32]);
    });

    test('a confirmed payment with no time goes to verifying, not pending', () {
      final undated = [
        for (final status in [
          SpPaymentStatus.confirmedUnverified,
          SpPaymentStatus.verified,
          SpPaymentStatus.verifyFailed,
        ])
          payment('${status.index}' * 64, null, status: status, height: 800),
      ];

      final grouped = SpState(
        history: [nextDay, ...undated, pending],
      ).historyByDay;

      expect(grouped.keys.toList(), [
        spPendingGroupKey,
        spVerifyingGroupKey,
        may13.millisecondsSinceEpoch,
      ]);
      expect(txidsOf(grouped[spPendingGroupKey]), ['dd' * 32]);
      expect(txidsOf(grouped[spVerifyingGroupKey]), hasLength(3));
    });

    test('orders the verifying group highest block first', () {
      final low = payment(
        '11' * 32,
        null,
        status: SpPaymentStatus.confirmedUnverified,
        height: 800,
      );
      final high = payment(
        '22' * 32,
        null,
        status: SpPaymentStatus.confirmedUnverified,
        height: 900,
      );

      final grouped = SpState(history: [low, high]).historyByDay;

      expect(txidsOf(grouped[spVerifyingGroupKey]), ['22' * 32, '11' * 32]);
    });

    test('an empty history gives an empty map', () {
      expect(SpState().historyByDay, isEmpty);
    });
  });
}
