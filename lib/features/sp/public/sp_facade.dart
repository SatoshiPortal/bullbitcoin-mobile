import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

// Part of the SP public surface: cross-feature consumers get these pure value
// objects (and the feature's failure family) via the facade, so they never
// import the feature's `domain/`.
export 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart'
    show SpBalance;
export 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart'
    show SpRecipient;
export 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart'
    show SpTxDraft;
export 'package:bb_mobile/features/sp/domain/entities/sp_update.dart'
    show SpUpdate, SpBalanceChanged, SpSetupChanged;
export 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart'
    show SpWallet;
export 'package:bb_mobile/features/sp/domain/sp_failure.dart' show SpFailure;

/// Public API of the Silent Payments feature. The ONLY entry point for
/// cross-feature interaction (wallet, settings). Exposes pure domain types
/// only; no FFI / application internals leak out.
///
/// Consumers must wrap this in their own feature's use case (per AGENTS.md
/// rule #4) and never call it directly from a BLoC.
class SpFacade {
  final GetSpWalletUsecase _getSpWalletUsecase;
  final IsSpScanningUsecase _isSpScanningUsecase;
  final CheckSpWalletSetupUsecase _checkSpWalletSetupUsecase;
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final RevokeSpWalletUsecase _revokeSpWalletUsecase;
  final WatchSpUpdatesUsecase _watchSpUpdatesUsecase;
  final ResyncSpListenerUsecase _resyncSpListenerUsecase;
  final ValidateSpRecipientUsecase _validateSpRecipientUsecase;
  final PrepareSpPaymentUsecase _prepareSpPaymentUsecase;
  final SendSpPaymentUsecase _sendSpPaymentUsecase;

  SpFacade({
    required this._getSpWalletUsecase,
    required this._isSpScanningUsecase,
    required this._checkSpWalletSetupUsecase,
    required this._getSpFeatureGateUsecase,
    required this._revokeSpWalletUsecase,
    required this._watchSpUpdatesUsecase,
    required this._resyncSpListenerUsecase,
    required this._validateSpRecipientUsecase,
    required this._prepareSpPaymentUsecase,
    required this._sendSpPaymentUsecase,
  });

  /// Whether the SP feature is enabled (superuser + dev mode gate). Cross-feature
  /// consumers (the wallet) read the gate through here instead of the settings.
  Future<bool> isFeatureEnabled() => _getSpFeatureGateUsecase.execute();

  /// Whether the SP wallet is set up (gated + sentinel-aware).
  Future<bool> isSetUp() => _checkSpWalletSetupUsecase.execute();

  /// Whether a scan is running (tracked in Dart, no FFI). Callers skip the
  /// wallet refresh while true so it never disposes the session mid-scan.
  bool get isScanning => _isSpScanningUsecase.execute();

  /// Reads a fresh snapshot from the live session without disposing it.
  /// `Ok(null)` when SP is not set up; `Err` on failure (e.g. a dispose still
  /// holds the inner lock) so the caller leaves its state intact and retries.
  Future<Result<SpWallet?, SpFailure>> refresh() async {
    try {
      return Ok(await _getSpWalletUsecase.execute());
    } catch (e) {
      return Err(SpUnexpected('SP refresh failed: $e'));
    }
  }

  /// Revoke the SP wallet (sentinel + on-disk delete + config delete). `Err`
  /// when the on-disk delete failed; the sentinel is already written so the
  /// wallet stays unloadable and the caller only surfaces a retry prompt.
  Future<Result<void, SpFailure>> revoke() => _revokeSpWalletUsecase.execute();

  /// Observe SP wallet changes (balance updates, setup created/revoked).
  Stream<SpUpdate> watchUpdates() => _watchSpUpdatesUsecase.execute();

  /// Restart the taproot electrum listener (reconnect + re-sync) on app
  /// foreground, so coins received while backgrounded are detected. `Ok(null)`
  /// when no session is live (a no-op); `Err` when the restart failed.
  Future<Result<void, SpFailure>> resyncListener() =>
      _resyncSpListenerUsecase.execute();

  Result<SpRecipient, SpFailure> validateRecipient({
    required String input,
    required BigInt amountSat,
    required bool isMax,
  }) => _validateSpRecipientUsecase.execute(
    input: input,
    amountSat: amountSat,
    isMax: isMax,
  );

  Future<Result<SpTxDraft, SpFailure>> preparePayment({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  }) => _prepareSpPaymentUsecase.execute(
    recipients: recipients,
    feerateSatVb: feerateSatVb,
  );

  Future<Result<String, SpFailure>> sendPayment({required SpTxDraft draft}) =>
      _sendSpPaymentUsecase.execute(draft: draft);
}
