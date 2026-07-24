/// A recoverable, non-fatal condition raised while a wallet is syncing. The
/// sync keeps running after a warning — it is advisory only, never a
/// terminal outcome (terminal success/failure is the [Result] a
/// `WalletSyncRepository.startSync` call resolves with).
///
/// `sealed` keeps this closed: every case is a coded classification, never a
/// carrier for the native payload (peer address, transaction id, raw BDK
/// warning string) that produced it — see each variant's [logMessage].
sealed class WalletSyncWarning {
  const WalletSyncWarning([this.logMessage]);

  /// For logs ONLY. MUST never reach the UI untranslated. Always a fixed,
  /// non-sensitive code — never native/user data.
  final String? logMessage;
}

/// Catch-all until a backend contributes a modeled variant.
final class WalletSyncUnexpectedWarning extends WalletSyncWarning {
  const WalletSyncUnexpectedWarning([super.logMessage]);
}

/// The compact-filter backend does not have enough peer connections yet and
/// is retrying. Maps `bdk.NeedConnectionsWarning`.
final class WalletSyncNeedsConnectionsWarning extends WalletSyncWarning {
  const WalletSyncNeedsConnectionsWarning() : super('cbf_need_connections');
}

/// A compact-filter peer timed out, could not be connected to, sent an
/// unsolicited message, or a P2P request otherwise failed. Coded only — no
/// peer identity ever reaches [logMessage]. Maps `bdk.PeerTimedOutWarning`,
/// `bdk.CouldNotConnectWarning`, `bdk.UnsolicitedMessageWarning`, and
/// `bdk.RequestFailedWarning`.
final class WalletSyncPeerIssueWarning extends WalletSyncWarning {
  const WalletSyncPeerIssueWarning() : super('cbf_peer_issue');
}

/// The compact-filter backend has no filters to serve the requested range
/// yet. Maps `bdk.NoCompactFiltersWarning`.
final class WalletSyncNoCompactFiltersWarning extends WalletSyncWarning {
  const WalletSyncNoCompactFiltersWarning() : super('cbf_no_compact_filters');
}

/// The compact-filter backend's current tip may be stale, or it is
/// evaluating a fork. Maps `bdk.PotentialStaleTipWarning` and
/// `bdk.EvaluatingForkWarning`.
final class WalletSyncStaleTipWarning extends WalletSyncWarning {
  const WalletSyncStaleTipWarning() : super('cbf_stale_tip');
}

/// A broadcast transaction was rejected by a compact-filter peer. The
/// transaction id and rejection reason never reach [logMessage] — Electrum
/// already owns this wallet's broadcast outcome. Maps
/// `bdk.TransactionRejectedWarning`.
final class WalletSyncTransactionRejectedWarning extends WalletSyncWarning {
  const WalletSyncTransactionRejectedWarning()
    : super('cbf_transaction_rejected');
}

/// An unexpected condition inside the compact-filter backend's native sync
/// loop. The native detail never reaches [logMessage]. Maps
/// `bdk.UnexpectedSyncExceptionWarning`.
final class WalletSyncUnexpectedSyncWarning extends WalletSyncWarning {
  const WalletSyncUnexpectedSyncWarning() : super('cbf_unexpected_sync');
}
