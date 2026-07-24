import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/cbf_spike_support.dart';

void main() {
  group('mapCbfSpikeInfo', () {
    test('maps connection milestones without payload data', () {
      expect(
        mapCbfSpikeInfo(bdk.ConnectionsMetInfo()).stage,
        CbfSpikeStage.connectionsMet,
      );
      expect(
        mapCbfSpikeInfo(bdk.SuccessfulHandshakeInfo()).stage,
        CbfSpikeStage.handshake,
      );
    });

    test('maps filter progress', () {
      final event = mapCbfSpikeInfo(
        bdk.ProgressInfo(chainHeight: 2500000, filtersDownloadedPercent: 42.5),
      );

      expect(event.stage, CbfSpikeStage.scanning);
      expect(event.chainHeight, 2500000);
      expect(event.filtersDownloadedPercent, 42.5);
    });

    test('maps received blocks without retaining the block hash', () {
      final event = mapCbfSpikeInfo(bdk.BlockReceivedInfo('block-hash'));

      expect(event.stage, CbfSpikeStage.blockReceived);
      expect(event.chainHeight, isNull);
      expect(event.filtersDownloadedPercent, isNull);
    });
  });

  test('CbfShutdownGuard calls native shutdown once', () {
    var calls = 0;
    final guard = CbfShutdownGuard(() => calls++);

    guard.shutdown();
    guard.shutdown();

    expect(calls, 1);
  });

  test('maps warnings without retaining native details', () {
    final rejected = mapCbfSpikeWarning(
      bdk.TransactionRejectedWarning(
        wtxid: 'sensitive-transaction-id',
        reason: 'sensitive-node-reason',
      ),
    );
    final unexpected = mapCbfSpikeWarning(
      bdk.UnexpectedSyncExceptionWarning('sensitive-native-detail'),
    );

    expect(rejected, 'transaction_rejected');
    expect(rejected, isNot(contains('sensitive')));
    expect(unexpected, 'unexpected_sync_exception');
    expect(unexpected, isNot(contains('sensitive')));
  });
}
