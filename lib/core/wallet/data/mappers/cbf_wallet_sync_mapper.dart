import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_warning.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// The scanning-progress fields [CbfWalletSyncMapper.toScanningProgress]
/// extracts from a `bdk.Info`. Never carries anything beyond height/percent
/// — no peer identity, no block hash.
class CbfScanningProgress {
  const CbfScanningProgress({
    required this.stage,
    required this.hasStartedDownloadingFilters,
    this.scannedPercent,
    this.chainHeight,
  });

  final WalletSyncScanStage stage;
  final double? scannedPercent;
  final int? chainHeight;

  /// Sticky once true: whether a `bdk.ProgressInfo` with a nonzero
  /// `filtersDownloadedPercent` has ever been observed this attempt. The
  /// caller (`CbfWalletDatasource`) must persist this per attempt and pass
  /// it back in as [CbfWalletSyncMapper.toScanningProgress]'s
  /// `hasStartedDownloadingFilters` argument on every later call, so a
  /// `ProgressInfo` that (rarely) reports `0` again after progress has
  /// started still classifies as [WalletSyncScanStage.downloadingFilters]
  /// rather than regressing to [WalletSyncScanStage.syncingHeaders].
  final bool hasStartedDownloadingFilters;
}

/// Maps `bull_sdk`/`bdk_dart`'s native CBF `Info` and `Warning` unions to
/// this app's domain [WalletSyncWarning] family, so no BDK type and no
/// native payload (peer address, transaction id, block hash, raw warning
/// string) crosses the `data/` boundary.
class CbfWalletSyncMapper {
  const CbfWalletSyncMapper._();

  /// Classifies a native `bdk.Info` into a sanitized [CbfScanningProgress].
  ///
  /// [hasStartedDownloadingFilters] must be the sticky flag this attempt's
  /// most recent [CbfScanningProgress] returned (`false` for the first
  /// call) — see that field's doc for why the classification of a
  /// `bdk.ProgressInfo` depends on it.
  static CbfScanningProgress toScanningProgress(
    bdk.Info info, {
    required bool hasStartedDownloadingFilters,
  }) => switch (info) {
    bdk.ProgressInfo(:final chainHeight, :final filtersDownloadedPercent) =>
      _progressStage(
        chainHeight: chainHeight,
        filtersDownloadedPercent: filtersDownloadedPercent,
        hasStartedDownloadingFilters: hasStartedDownloadingFilters,
      ),
    // Both carry no measurable data; both are surfaced as the same
    // "connected" milestone — see WalletSyncScanStage.connected's doc.
    bdk.ConnectionsMetInfo() ||
    bdk.SuccessfulHandshakeInfo() => CbfScanningProgress(
      stage: WalletSyncScanStage.connected,
      hasStartedDownloadingFilters: hasStartedDownloadingFilters,
    ),
    bdk.BlockReceivedInfo() => CbfScanningProgress(
      stage: WalletSyncScanStage.matchingBlocks,
      hasStartedDownloadingFilters: hasStartedDownloadingFilters,
    ),
    _ => CbfScanningProgress(
      stage: WalletSyncScanStage.connecting,
      hasStartedDownloadingFilters: hasStartedDownloadingFilters,
    ),
  };

  /// A `bdk.ProgressInfo` is [WalletSyncScanStage.syncingHeaders] until a
  /// nonzero [filtersDownloadedPercent] has been observed at least once,
  /// then [WalletSyncScanStage.downloadingFilters] for the rest of the
  /// attempt — the one-way transition [CbfScanningProgress.hasStartedDownloadingFilters]
  /// documents. [scannedPercent] is only ever populated for the latter: a
  /// `0` reported before progress has started describes header sync, not
  /// filter download, so it is withheld rather than shown as a misleading
  /// "0%" of filter progress.
  static CbfScanningProgress _progressStage({
    required int chainHeight,
    required double filtersDownloadedPercent,
    required bool hasStartedDownloadingFilters,
  }) {
    final started =
        hasStartedDownloadingFilters || filtersDownloadedPercent > 0;
    return CbfScanningProgress(
      stage: started
          ? WalletSyncScanStage.downloadingFilters
          : WalletSyncScanStage.syncingHeaders,
      scannedPercent: started ? filtersDownloadedPercent : null,
      chainHeight: chainHeight,
      hasStartedDownloadingFilters: started,
    );
  }

  static WalletSyncWarning toWarning(bdk.Warning warning) => switch (warning) {
    bdk.NeedConnectionsWarning() => const WalletSyncNeedsConnectionsWarning(),
    bdk.PeerTimedOutWarning() ||
    bdk.CouldNotConnectWarning() ||
    bdk.UnsolicitedMessageWarning() ||
    bdk.RequestFailedWarning() => const WalletSyncPeerIssueWarning(),
    bdk.NoCompactFiltersWarning() => const WalletSyncNoCompactFiltersWarning(),
    bdk.PotentialStaleTipWarning() ||
    bdk.EvaluatingForkWarning() => const WalletSyncStaleTipWarning(),
    bdk.TransactionRejectedWarning() =>
      const WalletSyncTransactionRejectedWarning(),
    bdk.UnexpectedSyncExceptionWarning() =>
      const WalletSyncUnexpectedSyncWarning(),
    _ => const WalletSyncUnexpectedWarning(),
  };
}
