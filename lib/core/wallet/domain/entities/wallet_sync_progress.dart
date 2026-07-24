import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_warning.dart';

/// Advisory, in-flight progress for a wallet sync, emitted by
/// `WalletSyncRepository.watchProgress()` while a sync for [walletId] is
/// running.
///
/// A sync's authoritative success/failure is still only ever reported by
/// the `Result` that `WalletSyncRepository.startSync` resolves with — this
/// stream's [WalletSyncCompleted]/[WalletSyncFailed]/[WalletSyncCancelled]
/// are advisory mirrors of that outcome for consumers (the app-wide
/// progress cubit) that never called `startSync` themselves and so would
/// otherwise never learn the attempt settled. [WalletSyncFailed] never
/// carries the raw error — see its own doc. Consumers that only care about
/// one wallet filter by [walletId].
sealed class WalletSyncProgress {
  const WalletSyncProgress(this.walletId);

  final String walletId;
}

/// A sync started for [walletId] on [backend]. Every backend's
/// `watchProgress` stamps its own identity here, so a consumer knows
/// immediately — with no need to wait for a backend-exclusive signal like
/// `WalletSyncScanning` — whether this attempt is worth tracking as a
/// compact-filter (CBF) sync.
final class WalletSyncStarted extends WalletSyncProgress {
  const WalletSyncStarted(super.walletId, this.backend);

  final BitcoinSyncBackend backend;
}

/// A sync for [walletId] is actively scanning.
///
/// [scannedPercent] is a 0-100 determinate estimate of compact-filter
/// download progress — only ever populated while [stage] is
/// [WalletSyncScanStage.downloadingFilters] — and null in every other
/// stage, including [WalletSyncScanStage.syncingHeaders]: the native
/// backend reports `filtersDownloadedPercent: 0` for that stage too, but
/// showing that raw `0` as "0%" would misrepresent header-sync progress as
/// filter-download progress, so it is deliberately withheld rather than
/// surfaced as a misleading percent. [chainHeight] is the local header
/// height the backend has observed so far when it can report one
/// (compact-filter sync); null for backends that do not surface a height
/// mid-scan. It is a local count only — never a percentage, and never
/// compared against a target height — see [WalletSyncScanStage.syncingHeaders].
enum WalletSyncScanStage {
  /// A sync attempt is running but the backend has not yet reported
  /// anything this enum can otherwise classify — the brief window right
  /// after [WalletSyncStarted] and before the first native event.
  connecting,

  /// The backend has established peer connections and/or completed a
  /// handshake with them. Carries no measurable progress.
  connected,

  /// The backend is syncing block headers: a `bdk.ProgressInfo` observed
  /// before this attempt has ever reported a nonzero
  /// `filtersDownloadedPercent`. [WalletSyncScanning.chainHeight] tracks the
  /// local header height reached so far; [WalletSyncScanning.scannedPercent]
  /// is deliberately null here (see the class doc).
  syncingHeaders,

  /// The backend is downloading compact block filters.
  /// [WalletSyncScanning.scannedPercent] is `bdk.ProgressInfo`'s own
  /// `filtersDownloadedPercent`, surfaced once it has been observed nonzero
  /// at least once this attempt. Classification is one-way: a later
  /// `ProgressInfo` that reports `0` again still classifies here rather
  /// than regressing to [syncingHeaders] — see `CbfWalletSyncMapper`.
  downloadingFilters,

  /// The backend is matching downloaded filters against the wallet's
  /// scripts. [WalletSyncScanning.receivedBlockCount] is how many blocks
  /// have matched so far this attempt; the underlying block hashes are
  /// never exposed outside the data layer.
  matchingBlocks,

  /// The scan's native update is being awaited, applied to the wallet, and
  /// persisted — a single opaque native call
  /// (`CbfNativeSession.awaitAndApplyUpdate`) with no further progress
  /// signal until it settles. Emitted exactly once, immediately before
  /// that call — never derived from a native info event.
  applyingUpdate,
}

final class WalletSyncScanning extends WalletSyncProgress {
  const WalletSyncScanning(
    super.walletId, {
    this.stage = WalletSyncScanStage.downloadingFilters,
    this.scannedPercent,
    this.chainHeight,
    this.receivedBlockCount,
    this.peerHandshakeCount,
  });

  /// A sanitized, backend-agnostic stage. It never identifies a peer, block,
  /// address, transaction, or precise chain position.
  final WalletSyncScanStage stage;
  final double? scannedPercent;
  final int? chainHeight;

  /// Count of block notifications seen during this attempt. The underlying
  /// block hashes are deliberately never exposed outside the data layer.
  final int? receivedBlockCount;

  /// Number of successful peer handshakes observed during this attempt.
  /// Peer identities and addresses never leave the data layer.
  final int? peerHandshakeCount;
}

/// A non-fatal condition was raised mid-sync for [walletId]; the sync kept
/// running.
final class WalletSyncWarningRaised extends WalletSyncProgress {
  const WalletSyncWarningRaised(super.walletId, this.warning);

  final WalletSyncWarning warning;
}

/// The sync for [walletId] finished successfully.
final class WalletSyncCompleted extends WalletSyncProgress {
  const WalletSyncCompleted(super.walletId);
}

/// Coarse, sanitized classification of why a sync for [WalletSyncFailed]
/// failed. Never derived from a raw exception message, wallet id, peer, or
/// descriptor — see `CbfWalletDatasource`'s logging discipline. Purely
/// advisory: the authoritative failure a caller of `startSync` should branch
/// on is the `WalletSyncFailure` its `Result` resolves with, not this
/// category.
enum WalletSyncFailureCategory {
  /// The compact block filter backend failed to build, connect, scan, or
  /// apply an update.
  compactBlockFilters,

  /// Every Electrum server failed, or an unmodeled Electrum-path error.
  electrum,
}

/// The sync for [walletId] settled on a failure. Emitted in addition to
/// (never instead of) the `Result` a `startSync` caller receives, so an
/// app-wide observer that only watches this stream (see
/// `WalletSyncProgressCubit`) still learns the attempt failed rather than
/// being left showing a stale in-progress state. [category] is a coarse,
/// sanitized classification — never the raw error.
final class WalletSyncFailed extends WalletSyncProgress {
  const WalletSyncFailed(super.walletId, this.category);

  final WalletSyncFailureCategory category;
}

/// The sync for [walletId] settled because it was torn down before
/// finishing — never by an ordinary `WalletSyncRepository.cancelSync` call,
/// which is a deliberate no-op under `CbfWalletDatasource`'s long-lived
/// session policy (a CBF session keeps running once started). The only two
/// triggers are `CbfWalletDatasource.cancelAndWait` (wallet deletion — the
/// on-disk state must not be mutated by a still-running session) and Tor
/// being enabled mid-session (CBF never routes through Tor). Emitted
/// instead of [WalletSyncCompleted]; the settled `Result` is still
/// `Ok(null)` (a deliberate teardown, never a failure — see
/// `CbfWalletDatasource`).
///
/// Only ever emitted by a backend with a native session to tear down.
/// Electrum's `cancelSync` is a documented no-op and never emits this — its
/// `watchProgress` only ever emits [WalletSyncStarted] followed by
/// [WalletSyncCompleted].
final class WalletSyncCancelled extends WalletSyncProgress {
  const WalletSyncCancelled(super.walletId);
}
