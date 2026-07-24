part of 'wallet_sync_progress_cubit.dart';

/// Where one wallet's advisory sync progress currently stands, as tracked by
/// [WalletSyncProgressCubit]. Purely presentational.
enum WalletSyncProgressPhase {
  /// A sync attempt started; no scan progress has been reported yet.
  connecting,

  /// The sync is actively scanning. [WalletSyncProgressEntry.scannedPercent]
  /// is a determinate 0-100 estimate while the backend reports one.
  scanning,

  /// The sync finished successfully. Retained for a short confirmation
  /// window (see [WalletSyncProgressCubit]) before the entry is removed.
  completed,

  /// The sync settled on a failure. Retained until the user retries (which
  /// resets the entry back to [connecting] once the fresh attempt's
  /// `WalletSyncStarted` arrives) or the wallet leaves compact-filter sync
  /// entirely.
  failed,
}

/// One wallet's latest advisory sync progress.
///
/// [isConfirmedCbf] is true for an attempt confirmed to be running on the
/// compact-filter (CBF) backend — either because its `WalletSyncStarted`
/// carried `BitcoinSyncBackend.compactBlockFilters` directly, or (for a
/// signal that can arrive with no preceding tracked `Started`, e.g. a setup
/// failure) because the signal itself is only ever tagged CBF, such as a
/// `WalletSyncFailed` with `WalletSyncFailureCategory.compactBlockFilters`.
/// Electrum's `watchProgress` only ever emits `WalletSyncStarted` tagged
/// `BitcoinSyncBackend.electrum`, followed by `WalletSyncCompleted` (or,
/// rarely, a `WalletSyncFailed` tagged
/// `WalletSyncFailureCategory.electrum`) — see `WalletSyncProgress`'s domain
/// doc. Consumers that must show CBF-specific UI (phase text, a cancel
/// control) key off this flag rather than [phase] alone, so an ordinary
/// Electrum sync's Started/Completed pair never triggers CBF-only UI.
class WalletSyncProgressEntry {
  const WalletSyncProgressEntry({
    required this.phase,
    this.scanStage,
    this.scannedPercent,
    this.chainHeight,
    this.receivedBlockCount = 0,
    this.peerHandshakeCount = 0,
    this.hasConnected = false,
    this.hasFilterProgress = false,
    this.hasMatchingBlocks = false,
    this.hasReachedApplyingUpdate = false,
    this.hasWarning = false,
    this.isConfirmedCbf = false,
  });

  final WalletSyncProgressPhase phase;

  final WalletSyncScanStage? scanStage;

  /// A 0-100 determinate estimate while [phase] is
  /// [WalletSyncProgressPhase.scanning] and the backend reports one; null
  /// for an indeterminate bar. Only ever populated while [scanStage] is
  /// [WalletSyncScanStage.downloadingFilters] — see that enum value's doc.
  final double? scannedPercent;

  /// Public chain state for the active CBF attempt. A local header height
  /// only — never a percentage, and never compared against a target
  /// height. It carries no wallet identifier beyond the map key already
  /// held by this presentation state.
  final int? chainHeight;
  final int receivedBlockCount;
  final int peerHandshakeCount;

  /// Sticky once true: [WalletSyncScanStage.connected] was reached at any
  /// point during this attempt, regardless of the current [scanStage].
  final bool hasConnected;

  /// Sticky once true: [WalletSyncScanStage.downloadingFilters] was
  /// reached at any point during this attempt.
  final bool hasFilterProgress;

  /// Sticky once true: the backend started reporting matching blocks.
  final bool hasMatchingBlocks;

  /// Sticky once true: [WalletSyncScanStage.applyingUpdate] was reached at
  /// any point during this attempt — kept visible even after the attempt
  /// settles as [WalletSyncProgressPhase.failed], since that is valuable
  /// diagnostic context ("it got as far as applying the update").
  final bool hasReachedApplyingUpdate;

  /// True if a non-fatal warning was raised at any point during this
  /// attempt. Advisory only — the sync keeps running; never carries the
  /// warning's raw payload (see `WalletSyncWarning`).
  final bool hasWarning;

  /// See the class doc.
  final bool isConfirmedCbf;

  WalletSyncProgressEntry copyWith({
    WalletSyncProgressPhase? phase,
    WalletSyncScanStage? scanStage,
    bool clearScanStage = false,
    double? scannedPercent,
    bool clearScannedPercent = false,
    int? chainHeight,
    bool clearChainHeight = false,
    int? receivedBlockCount,
    int? peerHandshakeCount,
    bool? hasConnected,
    bool? hasFilterProgress,
    bool? hasMatchingBlocks,
    bool? hasReachedApplyingUpdate,
    bool? hasWarning,
    bool? isConfirmedCbf,
  }) {
    return WalletSyncProgressEntry(
      phase: phase ?? this.phase,
      scanStage: clearScanStage ? null : (scanStage ?? this.scanStage),
      scannedPercent: clearScannedPercent
          ? null
          : (scannedPercent ?? this.scannedPercent),
      chainHeight: clearChainHeight ? null : (chainHeight ?? this.chainHeight),
      receivedBlockCount: receivedBlockCount ?? this.receivedBlockCount,
      peerHandshakeCount: peerHandshakeCount ?? this.peerHandshakeCount,
      hasConnected: hasConnected ?? this.hasConnected,
      hasFilterProgress: hasFilterProgress ?? this.hasFilterProgress,
      hasMatchingBlocks: hasMatchingBlocks ?? this.hasMatchingBlocks,
      hasReachedApplyingUpdate:
          hasReachedApplyingUpdate ?? this.hasReachedApplyingUpdate,
      hasWarning: hasWarning ?? this.hasWarning,
      isConfirmedCbf: isConfirmedCbf ?? this.isConfirmedCbf,
    );
  }
}

/// Immutable snapshot of every wallet's latest advisory sync progress, keyed
/// by wallet id. See [WalletSyncProgressCubit].
class WalletSyncProgressState {
  const WalletSyncProgressState({this.entries = const {}});

  final Map<String, WalletSyncProgressEntry> entries;

  WalletSyncProgressEntry? forWallet(String walletId) => entries[walletId];

  WalletSyncProgressState copyWith({
    Map<String, WalletSyncProgressEntry>? entries,
  }) {
    return WalletSyncProgressState(entries: entries ?? this.entries);
  }
}
