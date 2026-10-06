import 'package:bb_mobile/features/sp/data/mappers/sp_notification_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpNotificationMapper scan events', () {
    test('scanStarted carries the block range', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.scanStarted(from: 100, to: 250),
      );

      expect(mapped, isA<SpScanStarted>());
      expect((mapped as SpScanStarted).from, 100);
      expect(mapped.to, 250);
    });

    test('scanReceiveProgress carries current and end', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.scanReceiveProgress(current: 7, end: 9),
      );

      expect(mapped, isA<SpScanReceiveProgress>());
      expect((mapped as SpScanReceiveProgress).current, 7);
      expect(mapped.end, 9);
    });

    test('scanSpendProgress maps to its own type, not receive progress', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.scanSpendProgress(current: 3, end: 4),
      );

      expect(mapped, isA<SpScanSpendProgress>());
      expect(mapped, isNot(isA<SpScanReceiveProgress>()));
      expect((mapped as SpScanSpendProgress).current, 3);
      expect(mapped.end, 4);
    });

    test('scanCompleted and scanStopped map to their singletons', () {
      expect(
        SpNotificationMapper.toDomain(const bwk.SpNotification.scanCompleted()),
        isA<SpScanCompleted>(),
      );
      expect(
        SpNotificationMapper.toDomain(const bwk.SpNotification.scanStopped()),
        isA<SpScanStopped>(),
      );
    });

    test('scanFailed keeps the upstream message', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.scanFailed(message: 'blindbit unreachable'),
      );

      expect(mapped, isA<SpScanFailed>());
      expect(
        (mapped as SpScanFailed).failure.logMessage,
        'blindbit unreachable',
      );
    });
  });

  group('SpNotificationMapper output and broadcast events', () {
    test('newOutput wraps the amount in Sats', () {
      final mapped = SpNotificationMapper.toDomain(
        bwk.SpNotification.newOutput(
          outpoint: 'abc:1',
          amountSat: BigInt.from(4200),
        ),
      );

      expect(mapped, isA<SpNewOutput>());
      expect((mapped as SpNewOutput).outpoint, 'abc:1');
      expect(mapped.amountSat, Sats.fromInt(4200));
    });

    test('outputSpent carries the outpoint unparsed', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.outputSpent(outpoint: 'abc:2'),
      );

      expect(mapped, isA<SpOutputSpent>());
      expect((mapped as SpOutputSpent).outpoint, 'abc:2');
    });

    test('broadcasted carries the txid', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.broadcasted(txid: 'deadbeef'),
      );

      expect(mapped, isA<SpBroadcasted>());
      expect((mapped as SpBroadcasted).txid, 'deadbeef');
    });

    test('broadcastFailed keeps the upstream message', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.broadcastFailed(message: 'rejected by node'),
      );

      expect(mapped, isA<SpBroadcastFailed>());
      expect((mapped as SpBroadcastFailed).message, 'rejected by node');
    });

    test('backendOffline maps to its singleton', () {
      expect(
        SpNotificationMapper.toDomain(
          const bwk.SpNotification.backendOffline(),
        ),
        isA<SpBackendOffline>(),
      );
    });

    test('paymentHistoryUpdated maps to its singleton', () {
      expect(
        SpNotificationMapper.toDomain(
          const bwk.SpNotification.paymentHistoryUpdated(),
        ),
        isA<SpPaymentHistoryUpdated>(),
      );
    });
  });

  group('SpNotificationMapper electrum push', () {
    test('electrumTx maps the coin source and the confirmed height', () {
      final mapped = SpNotificationMapper.toDomain(
        bwk.SpNotification.electrumTx(
          kind: bwk.CoinSource.taproot,
          txid: 'cafe',
          amountSat: BigInt.from(999),
          height: 800001,
        ),
      );

      expect(mapped, isA<SpElectrumTx>());
      final tx = mapped as SpElectrumTx;
      expect(tx.kind, SpCoinSource.taproot);
      expect(tx.txid, 'cafe');
      expect(tx.amountSat, Sats.fromInt(999));
      expect(tx.height, 800001);
    });

    test('electrumTx keeps a null height for an unconfirmed push', () {
      final mapped = SpNotificationMapper.toDomain(
        bwk.SpNotification.electrumTx(
          kind: bwk.CoinSource.sp,
          txid: 'cafe',
          amountSat: BigInt.zero,
          height: null,
        ),
      );

      expect((mapped as SpElectrumTx).height, isNull);
      expect(mapped.amountSat, Sats.zero);
    });
  });

  group('SpNotificationMapper header validation', () {
    test('headerProgressStarted maps the replay phase and the range', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.headerProgressStarted(
          phase: bwk.HeaderProgressPhase.replay,
          start: 10,
          end: 20,
        ),
      );

      expect(mapped, isA<SpHeaderProgressStarted>());
      final started = mapped as SpHeaderProgressStarted;
      expect(started.phase, SpHeaderValidationPhase.replay);
      expect(started.start, 10);
      expect(started.end, 20);
    });

    test('headerProgress maps the initialSync phase and the counters', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.headerProgress(
          phase: bwk.HeaderProgressPhase.initialSync,
          current: 15,
          end: 20,
        ),
      );

      expect(mapped, isA<SpHeaderProgress>());
      final progress = mapped as SpHeaderProgress;
      expect(progress.phase, SpHeaderValidationPhase.initialSync);
      expect(progress.current, 15);
      expect(progress.end, 20);
    });

    test('headerProgressCompleted carries the phase', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.headerProgressCompleted(
          phase: bwk.HeaderProgressPhase.initialSync,
        ),
      );

      expect(mapped, isA<SpHeaderProgressCompleted>());
      expect(
        (mapped as SpHeaderProgressCompleted).phase,
        SpHeaderValidationPhase.initialSync,
      );
    });

    test('headerProgressFailed carries the phase', () {
      final mapped = SpNotificationMapper.toDomain(
        const bwk.SpNotification.headerProgressFailed(
          phase: bwk.HeaderProgressPhase.replay,
        ),
      );

      expect(mapped, isA<SpHeaderProgressFailed>());
      expect(
        (mapped as SpHeaderProgressFailed).phase,
        SpHeaderValidationPhase.replay,
      );
    });
  });
}
