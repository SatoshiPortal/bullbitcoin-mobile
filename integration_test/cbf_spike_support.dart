import 'package:bull_sdk/bdk.dart' as bdk;

enum CbfSpikeStage {
  connectionsMet,
  handshake,
  scanning,
  blockReceived,
  unknown,
}

class CbfSpikeEvent {
  final CbfSpikeStage stage;
  final int? chainHeight;
  final double? filtersDownloadedPercent;

  const CbfSpikeEvent({
    required this.stage,
    this.chainHeight,
    this.filtersDownloadedPercent,
  });
}

CbfSpikeEvent mapCbfSpikeInfo(bdk.Info info) => switch (info) {
  bdk.ConnectionsMetInfo() => const CbfSpikeEvent(
    stage: CbfSpikeStage.connectionsMet,
  ),
  bdk.SuccessfulHandshakeInfo() => const CbfSpikeEvent(
    stage: CbfSpikeStage.handshake,
  ),
  bdk.ProgressInfo(:final chainHeight, :final filtersDownloadedPercent) =>
    CbfSpikeEvent(
      stage: CbfSpikeStage.scanning,
      chainHeight: chainHeight,
      filtersDownloadedPercent: filtersDownloadedPercent,
    ),
  bdk.BlockReceivedInfo() => const CbfSpikeEvent(
    stage: CbfSpikeStage.blockReceived,
  ),
  _ => const CbfSpikeEvent(stage: CbfSpikeStage.unknown),
};

String mapCbfSpikeWarning(bdk.Warning warning) => switch (warning) {
  bdk.NeedConnectionsWarning() => 'need_connections',
  bdk.PeerTimedOutWarning() => 'peer_timed_out',
  bdk.CouldNotConnectWarning() => 'could_not_connect',
  bdk.NoCompactFiltersWarning() => 'no_compact_filters',
  bdk.PotentialStaleTipWarning() => 'potential_stale_tip',
  bdk.UnsolicitedMessageWarning() => 'unsolicited_message',
  bdk.TransactionRejectedWarning() => 'transaction_rejected',
  bdk.EvaluatingForkWarning() => 'evaluating_fork',
  bdk.UnexpectedSyncExceptionWarning() => 'unexpected_sync_exception',
  bdk.RequestFailedWarning() => 'request_failed',
  _ => 'unknown',
};

class CbfShutdownGuard {
  final void Function() _shutdown;
  bool _isShutdown = false;

  CbfShutdownGuard(this._shutdown);

  void shutdown() {
    if (_isShutdown) return;
    _isShutdown = true;
    try {
      _shutdown();
    } on bdk.NodeStoppedCbfException {
      // The peer set may have exhausted before the caller requests shutdown.
    }
  }
}
