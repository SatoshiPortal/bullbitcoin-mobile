import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/presentation/sp_notification_console_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpNotificationConsoleText', () {
    test('scan lifecycle variants', () {
      expect(const SpScanStarted(1, 9).consoleText, 'ScanStarted 1 -> 9');
      expect(
        const SpScanReceiveProgress(5, 9).consoleText,
        'ScanReceiveProgress 5 / 9',
      );
      expect(
        const SpScanSpendProgress(3, 9).consoleText,
        'ScanSpendProgress 3 / 9',
      );
      expect(const SpScanCompleted().consoleText, 'ScanCompleted');
      expect(const SpScanStopped().consoleText, 'ScanStopped');
      expect(
        const SpScanFailed(SpUnexpected('boom')).consoleText,
        'ScanFailed: boom',
      );
    });

    test('coin variants', () {
      expect(
        SpNewOutput('ab:0', Sats.fromInt(1000)).consoleText,
        'NewOutput ab:0 1000sat',
      );
      expect(const SpOutputSpent('ab:0').consoleText, 'OutputSpent ab:0');
      expect(const SpBackendOffline().consoleText, 'BackendOffline');
    });

    test('electrum tx shows kind, txid, amount and height', () {
      expect(
        SpElectrumTx(
          kind: SpCoinSource.taproot,
          txid: 'deadbeef',
          amountSat: Sats.fromInt(2500),
          height: 210,
        ).consoleText,
        'ElectrumTx taproot deadbeef 2500sat @210',
      );
      expect(
        SpElectrumTx(
          kind: SpCoinSource.segwit,
          txid: 'cafe',
          amountSat: Sats.fromInt(1),
        ).consoleText,
        'ElectrumTx segwit cafe 1sat',
      );
    });
  });
}
