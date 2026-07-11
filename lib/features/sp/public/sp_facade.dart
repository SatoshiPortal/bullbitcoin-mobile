import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/refresh_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';

// Part of the SP public surface: cross-feature consumers get these pure value
// objects via the facade, so they never import the feature's `domain/`.
export 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart' show SpBalance;
export 'package:bb_mobile/features/sp/domain/entities/sp_update.dart'
    show SpUpdate, SpBalanceChanged, SpSetupChanged;
export 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart' show SpWallet;

/// Public API of the Silent Payments feature. The ONLY entry point for
/// cross-feature interaction (wallet, settings). Exposes pure domain types
/// only; no FFI / application internals leak out.
///
/// Consumers must wrap this in their own feature's use case (per AGENTS.md
/// rule #4) and never call it directly from a BLoC.
class SpFacade {
  final RefreshSpWalletUsecase _refreshSpWalletUsecase;
  final GetSpWalletUsecase _getSpWalletUsecase;
  final CheckSpWalletSetupUsecase _checkSpWalletSetupUsecase;
  final RevokeSpWalletUsecase _revokeSpWalletUsecase;
  final WatchSpUpdatesUsecase _watchSpUpdatesUsecase;
  final ResyncSpListenerUsecase _resyncSpListenerUsecase;

  SpFacade({
    required this._refreshSpWalletUsecase,
    required this._getSpWalletUsecase,
    required this._checkSpWalletSetupUsecase,
    required this._revokeSpWalletUsecase,
    required this._watchSpUpdatesUsecase,
    required this._resyncSpListenerUsecase,
  });

  /// Whether the SP wallet is set up (gated + sentinel-aware).
  Future<bool> isSetUp() => _checkSpWalletSetupUsecase.execute();

  /// Whether a scan is running (tracked in Dart, no FFI). Callers skip the
  /// wallet refresh while true so it never disposes the session mid-scan.
  bool get isScanning => _refreshSpWalletUsecase.isScanning;

  /// Reads a fresh snapshot from the live session without disposing it.
  /// Rethrows on dispose timeout so the caller can leave its state intact and
  /// retry later.
  Future<SpWallet?> refresh() => _refreshSpWalletUsecase.execute();

  /// Load the current snapshot without tearing down the session first.
  Future<SpWallet?> getWallet() => _getSpWalletUsecase.execute();

  /// Revoke the SP wallet (sentinel + on-disk delete + config delete).
  Future<void> revoke() => _revokeSpWalletUsecase.execute();

  /// Observe SP wallet changes (balance updates, setup created/revoked).
  Stream<SpUpdate> watchUpdates() => _watchSpUpdatesUsecase.execute();

  /// Restart the taproot electrum listener (reconnect + re-sync) on app
  /// foreground, so coins received while backgrounded are detected. No-op when
  /// no session is live.
  Future<void> resyncListener() => _resyncSpListenerUsecase.execute();
}
