import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_set_up_now_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

// Part of the SP public surface: cross-feature consumers get these pure value
// objects (and the feature's failure family) via the facade, so they never
// import the feature's `domain/`.
export 'package:bb_mobile/features/sp/domain/entities/sp_address.dart'
    show SpAddress;
export 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart'
    show SpAddressKind;
export 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart'
    show SpBalance;
// The variants come with the sealed base on purpose: without them a consumer
// can neither switch exhaustively nor build one.
export 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart'
    show SpRecipient, SpRecipientSp, SpRecipientStandard;
export 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart'
    show SpTxDraft;
export 'package:bb_mobile/features/sp/domain/entities/sp_update.dart'
    show SpUpdate, SpBalanceChanged, SpSetupChanged, SpChainTipChanged;
export 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart'
    show SpWallet;
// The sealed base plus every variant, so a consumer can switch on it
// exhaustively (AGENTS.md rule #11). Named one by one, never a blanket export:
// the list is the contract.
export 'package:bb_mobile/features/sp/domain/sp_failure.dart'
    show
        SpFailure,
        SpRequiresSuperuser,
        SpRequiresDevMode,
        SpNotSetUp,
        SpAlreadySetUp,
        SpSessionBusy,
        SpScanBusy,
        SpSimulationDrifted,
        SpBackendUnreachable,
        SpConfigInvalid,
        SpSetupCleanupFailed,
        SpAmountBelowMinimum,
        SpAmountExceedsBalance,
        SpAddressNetworkMismatch,
        SpInvalidAddress,
        SpBroadcastUncertain,
        SpUnexpected;
// Raised by the composition root when a sync tick failed, so the sync
// coordinator sees a failure without importing the feature's internals.
export 'package:bb_mobile/features/sp/sp_sync_exception.dart'
    show SpSyncException;
// Route ids only, so wallet and settings can navigate into SP without
// importing the feature's router.
export 'package:bb_mobile/features/sp/ui/sp_router.dart'
    show SpRoute, SpSetupRoute;

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
  final IsSpSetUpNowUsecase _isSpSetUpNowUsecase;
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final GetSpNetworkUsecase _getSpNetworkUsecase;
  final RevokeSpWalletUsecase _revokeSpWalletUsecase;
  final WatchSpUpdatesUsecase _watchSpUpdatesUsecase;
  final SyncSpWalletUsecase _syncSpWalletUsecase;
  final ValidateSpRecipientUsecase _validateSpRecipientUsecase;
  final ValidateSpAmountUsecase _validateSpAmountUsecase;
  final PrepareSpPaymentUsecase _prepareSpPaymentUsecase;
  final SendSpPaymentUsecase _sendSpPaymentUsecase;

  SpFacade({
    required this._getSpWalletUsecase,
    required this._isSpScanningUsecase,
    required this._checkSpWalletSetupUsecase,
    required this._isSpSetUpNowUsecase,
    required this._getSpFeatureGateUsecase,
    required this._getSpNetworkUsecase,
    required this._revokeSpWalletUsecase,
    required this._watchSpUpdatesUsecase,
    required this._syncSpWalletUsecase,
    required this._validateSpRecipientUsecase,
    required this._validateSpAmountUsecase,
    required this._prepareSpPaymentUsecase,
    required this._sendSpPaymentUsecase,
  });

  /// Whether the SP feature is enabled (superuser + dev mode gate). Cross-feature
  /// consumers (the wallet) read the gate through here instead of the settings.
  Future<bool> isFeatureEnabled() => _getSpFeatureGateUsecase.execute();

  /// Whether the SP wallet is set up (gated + sentinel-aware). `Err` when the
  /// stored config or the revoke sentinel could not be read, so a failed read
  /// is never mistaken for "not set up".
  Future<Result<bool, SpFailure>> isSetUp() =>
      _checkSpWalletSetupUsecase.execute();

  /// Synchronous view of [isSetUp], for the route gate, which cannot await.
  /// Refreshed by [isSetUp] and set directly by create and revoke.
  bool get isSetUpNow => _isSpSetUpNowUsecase.execute();

  /// Whether a scan is running (tracked in Dart, no FFI). Callers skip the
  /// wallet refresh while true so it never disposes the session mid-scan.
  bool get isScanning => _isSpScanningUsecase.execute();

  /// Reads a fresh snapshot from the live session without disposing it.
  /// `Ok(null)` when SP is not set up; `Err` on failure (e.g. a dispose still
  /// holds the inner lock) so the caller leaves its state intact and retries.
  ///
  /// No try/catch here on purpose: the adapter is the one boundary that turns
  /// a thrown FFI error into a failure (AGENTS.md rule #11), so the facade only
  /// forwards what the use case already returns.
  Future<Result<SpWallet?, SpFailure>> refresh() =>
      _getSpWalletUsecase.execute();

  /// Revoke the SP wallet (sentinel + on-disk delete + config delete). `Err`
  /// when the on-disk delete failed; the sentinel is already written so the
  /// wallet stays unloadable and the caller only surfaces a retry prompt.
  Future<Result<void, SpFailure>> revoke() => _revokeSpWalletUsecase.execute();

  /// Observe SP wallet changes (balance updates, setup created/revoked).
  Stream<SpUpdate> watchUpdates() => _watchSpUpdatesUsecase.execute();

  /// Run the SP side of a sync tick: restart the taproot electrum listener so
  /// coins received while backgrounded are detected, then resume the chain scan
  /// when the wallet is close enough to the tip. `Ok(null)` when there is
  /// nothing to do; `Err` when the listener restart or the scan failed.
  Future<Result<void, SpFailure>> syncWallet() =>
      _syncSpWalletUsecase.execute();

  /// The network the SP wallet runs on. `Ok(null)` when no session is live (a
  /// genuine unknown); `Err` on a read failure, so a caller can fail closed
  /// rather than assume mainnet.
  Result<BitcoinNetwork?, SpFailure> network() =>
      _getSpNetworkUsecase.execute();

  /// Up-front check that the amount is above zero and within the spendable
  /// balance. Rust `prepare()` stays the authority on fee-inclusive
  /// feasibility; this only blocks advancing on an obviously bad amount.
  Result<Sats, SpFailure> validateAmount(Sats amountSat) =>
      _validateSpAmountUsecase.execute(amountSat);

  Future<Result<SpRecipient, SpFailure>> validateRecipient({
    required String input,
    required Sats amountSat,
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
