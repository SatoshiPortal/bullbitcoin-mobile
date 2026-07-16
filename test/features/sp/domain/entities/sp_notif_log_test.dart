import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatSpNotification', () {
    test('scan lifecycle variants', () {
      expect(
        formatSpNotification(const SpScanStarted(1, 9)),
        'ScanStarted 1 -> 9',
      );
      expect(
        formatSpNotification(const SpScanReceiveProgress(5, 9)),
        'ScanReceiveProgress 5 / 9',
      );
      expect(
        formatSpNotification(const SpScanSpendProgress(3, 9)),
        'ScanSpendProgress 3 / 9',
      );
      expect(formatSpNotification(const SpScanCompleted()), 'ScanCompleted');
      expect(formatSpNotification(const SpScanStopped()), 'ScanStopped');
      expect(
        formatSpNotification(const SpScanFailed('boom')),
        'ScanFailed: boom',
      );
    });

    test('coin variants', () {
      expect(
        formatSpNotification(SpNewOutput('ab:0', BigInt.from(1000))),
        'NewOutput ab:0 1000sat',
      );
      expect(
        formatSpNotification(const SpOutputSpent('ab:0')),
        'OutputSpent ab:0',
      );
      expect(formatSpNotification(const SpBackendOffline()), 'BackendOffline');
    });

    test('electrum tx shows kind, txid, amount and height', () {
      expect(
        formatSpNotification(
          SpElectrumTx(
            kind: SpCoinSource.taproot,
            txid: 'deadbeef',
            amountSat: BigInt.from(2500),
            height: 210,
          ),
        ),
        'ElectrumTx taproot deadbeef 2500sat @210',
      );
      expect(
        formatSpNotification(
          SpElectrumTx(
            kind: SpCoinSource.segwit,
            txid: 'cafe',
            amountSat: BigInt.from(1),
          ),
        ),
        'ElectrumTx segwit cafe 1sat',
      );
    });
  });
}
