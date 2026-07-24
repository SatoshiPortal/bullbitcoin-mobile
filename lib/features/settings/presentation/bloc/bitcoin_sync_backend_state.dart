part of 'bitcoin_sync_backend_cubit.dart';

/// Where a developer-initiated compact-filter sync attempt currently stands
/// for one wallet. Purely presentational — the terminal success/failure of
/// an attempt is what moves this out of [connecting]/[scanning], never a
/// cause on its own.
enum BitcoinSyncBackendPhase { idle, connecting, scanning, completed, failed }

/// Why a [BitcoinSyncBackendPhase.failed] attempt failed — coarse enough for
/// the tile to pick a message and decide whether Retry makes sense, never
/// the raw [Failure.logMessage].
enum BitcoinSyncBackendFailureReason {
  /// The compact-filter backend itself failed (build/connect/scan/apply), or
  /// an unmodeled error — retrying may succeed.
  retriable,

  /// The user has Tor proxy enabled; V1 compact-filter sync does not route
  /// through Tor. Retrying without turning Tor off first will fail again.
  torUnsupported,

  /// The developer/beta gate is closed for this build/settings combination.
  /// Retrying changes nothing until the build or settings change.
  gateClosed,
}

class BitcoinSyncBackendState {
  const BitcoinSyncBackendState({
    this.isLoading = true,
    this.backend = BitcoinSyncBackend.electrum,
    this.phase = BitcoinSyncBackendPhase.idle,
    this.scannedPercent,
    this.failureReason,
  });

  /// True until the wallet's persisted [backend] choice has been read once.
  final bool isLoading;

  /// The wallet's persisted sync backend choice.
  final BitcoinSyncBackend backend;

  /// The in-flight attempt's phase; [BitcoinSyncBackendPhase.idle] when no
  /// compact-filter attempt is running.
  final BitcoinSyncBackendPhase phase;

  /// A 0-100 determinate estimate while [phase] is
  /// [BitcoinSyncBackendPhase.scanning], when the backend reports one; null
  /// for an indeterminate bar.
  final double? scannedPercent;

  /// Set alongside [BitcoinSyncBackendPhase.failed]; null otherwise. Drives
  /// which message the tile shows and whether Retry is offered — see
  /// [BitcoinSyncBackendFailureReason].
  final BitcoinSyncBackendFailureReason? failureReason;

  bool get isCompactBlockFiltersEnabled =>
      backend == BitcoinSyncBackend.compactBlockFilters;

  bool get isSyncing =>
      phase == BitcoinSyncBackendPhase.connecting ||
      phase == BitcoinSyncBackendPhase.scanning;

  /// Whether a Retry control should be offered for the current
  /// [BitcoinSyncBackendPhase.failed] attempt. False for a Tor-unsupported
  /// or developer-gate-closed failure — retrying without changing the
  /// underlying setting/build would just fail again the same way.
  bool get canRetry =>
      phase == BitcoinSyncBackendPhase.failed &&
      failureReason == BitcoinSyncBackendFailureReason.retriable;

  BitcoinSyncBackendState copyWith({
    bool? isLoading,
    BitcoinSyncBackend? backend,
    BitcoinSyncBackendPhase? phase,
    double? scannedPercent,
    bool clearScannedPercent = false,
    BitcoinSyncBackendFailureReason? failureReason,
    bool clearFailureReason = false,
  }) {
    return BitcoinSyncBackendState(
      isLoading: isLoading ?? this.isLoading,
      backend: backend ?? this.backend,
      phase: phase ?? this.phase,
      scannedPercent: clearScannedPercent
          ? null
          : (scannedPercent ?? this.scannedPercent),
      failureReason: clearFailureReason
          ? null
          : (failureReason ?? this.failureReason),
    );
  }
}
