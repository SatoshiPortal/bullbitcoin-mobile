part of 'wallet_initial_sync_cubit.dart';

/// Where `WalletInitialSyncCubit`'s own dedicated attempt currently stands.
/// Purely presentational, and purely about this screen's Continue/Skip
/// gating — the staged progress diagnostics shown alongside it still come
/// from the app-wide `WalletSyncProgressCard`/`WalletSyncProgressCubit`.
enum WalletInitialSyncPhase {
  /// Re-verifying the wallet's persisted backend really is
  /// `BitcoinSyncBackend.compactBlockFilters` before starting anything —
  /// see `WalletInitialSyncCubit`. The initial phase for every fresh
  /// instance.
  verifying,

  /// A sync attempt started (or was joined already running); no scan
  /// progress has been reported yet.
  connecting,

  /// The sync is actively scanning.
  scanning,

  /// The attempt finished successfully. Terminal — never reset except by a
  /// fresh `WalletInitialSyncCubit` instance (a new visit to this route).
  completed,

  /// The attempt settled on a failure, or this cubit's own CBF
  /// verification failed before a sync was ever attempted. Terminal until
  /// [WalletInitialSyncCubit.retry] (or a fresh `WalletSyncStarted` from
  /// the shared progress stream) runs it again.
  failed,
}

class WalletInitialSyncState {
  const WalletInitialSyncState({
    this.phase = WalletInitialSyncPhase.verifying,
  });

  final WalletInitialSyncPhase phase;

  bool get isCompleted => phase == WalletInitialSyncPhase.completed;

  bool get isFailed => phase == WalletInitialSyncPhase.failed;

  WalletInitialSyncState copyWith({WalletInitialSyncPhase? phase}) =>
      WalletInitialSyncState(phase: phase ?? this.phase);
}
