import 'package:bb_mobile/core/wallet/data/mappers/cbf_wallet_sync_mapper.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_warning.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CbfWalletSyncMapper.toScanningProgress', () {
    test('a ProgressInfo reporting 0% filter progress classifies as '
        'syncingHeaders, carrying chainHeight but withholding a misleading '
        '"0%" filter percent', () {
      final progress = CbfWalletSyncMapper.toScanningProgress(
        bdk.ProgressInfo(chainHeight: 500000, filtersDownloadedPercent: 0),
        hasStartedDownloadingFilters: false,
      );

      expect(progress.stage, WalletSyncScanStage.syncingHeaders);
      expect(progress.chainHeight, 500000);
      expect(progress.scannedPercent, isNull);
      expect(progress.hasStartedDownloadingFilters, isFalse);
    });

    test('a ProgressInfo reporting a nonzero filter percent classifies as '
        'downloadingFilters, carrying both chainHeight and the percent', () {
      final progress = CbfWalletSyncMapper.toScanningProgress(
        bdk.ProgressInfo(chainHeight: 2500000, filtersDownloadedPercent: 42.5),
        hasStartedDownloadingFilters: false,
      );

      expect(progress.stage, WalletSyncScanStage.downloadingFilters);
      expect(progress.chainHeight, 2500000);
      expect(progress.scannedPercent, 42.5);
      expect(progress.hasStartedDownloadingFilters, isTrue);
    });

    test('classification is one-way: once a nonzero filter percent has been '
        'seen this attempt, a later ProgressInfo reporting 0% again still '
        'classifies as downloadingFilters instead of regressing to '
        'syncingHeaders', () {
      final progress = CbfWalletSyncMapper.toScanningProgress(
        bdk.ProgressInfo(chainHeight: 500001, filtersDownloadedPercent: 0),
        hasStartedDownloadingFilters: true,
      );

      expect(progress.stage, WalletSyncScanStage.downloadingFilters);
      expect(progress.scannedPercent, 0);
      expect(progress.hasStartedDownloadingFilters, isTrue);
    });

    test('ConnectionsMetInfo and SuccessfulHandshakeInfo both classify as '
        'connected, carrying no measurable data', () {
      for (final info in [
        bdk.ConnectionsMetInfo(),
        bdk.SuccessfulHandshakeInfo(),
      ]) {
        final progress = CbfWalletSyncMapper.toScanningProgress(
          info,
          hasStartedDownloadingFilters: false,
        );

        expect(progress.stage, WalletSyncScanStage.connected);
        expect(progress.chainHeight, isNull);
        expect(progress.scannedPercent, isNull);
      }
    });

    test('BlockReceivedInfo classifies as matchingBlocks and never surfaces '
        'the underlying block hash', () {
      final progress = CbfWalletSyncMapper.toScanningProgress(
        bdk.BlockReceivedInfo('sensitive-block-hash'),
        hasStartedDownloadingFilters: true,
      );

      expect(progress.stage, WalletSyncScanStage.matchingBlocks);
      expect(progress.chainHeight, isNull);
      expect(progress.scannedPercent, isNull);
    });

    test('a true hasStartedDownloadingFilters flag passes through untouched '
        'for non-ProgressInfo variants', () {
      final progress = CbfWalletSyncMapper.toScanningProgress(
        bdk.ConnectionsMetInfo(),
        hasStartedDownloadingFilters: true,
      );

      expect(progress.hasStartedDownloadingFilters, isTrue);
    });
  });

  group('CbfWalletSyncMapper.toWarning', () {
    test('maps every native warning to a coded, payload-free domain type', () {
      final cases = <bdk.Warning, Type>{
        bdk.NeedConnectionsWarning(): WalletSyncNeedsConnectionsWarning,
        bdk.PeerTimedOutWarning(): WalletSyncPeerIssueWarning,
        bdk.CouldNotConnectWarning(): WalletSyncPeerIssueWarning,
        bdk.UnsolicitedMessageWarning(): WalletSyncPeerIssueWarning,
        bdk.RequestFailedWarning(): WalletSyncPeerIssueWarning,
        bdk.NoCompactFiltersWarning(): WalletSyncNoCompactFiltersWarning,
        bdk.PotentialStaleTipWarning(): WalletSyncStaleTipWarning,
        bdk.EvaluatingForkWarning(): WalletSyncStaleTipWarning,
        bdk.TransactionRejectedWarning(
          wtxid: 'sensitive-wtxid',
          reason: 'sensitive-reason',
        ): WalletSyncTransactionRejectedWarning,
        bdk.UnexpectedSyncExceptionWarning('sensitive-native-detail'):
            WalletSyncUnexpectedSyncWarning,
      };

      for (final entry in cases.entries) {
        final warning = CbfWalletSyncMapper.toWarning(entry.key);

        expect(warning.runtimeType, entry.value);
        expect(warning.logMessage, isNotNull);
        expect(warning.logMessage, isNot(contains('sensitive')));
      }
    });
  });
}
