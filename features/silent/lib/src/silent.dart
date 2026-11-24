import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:silent/src/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_network_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_set_up_now_usecase.dart';
import 'package:silent/src/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:silent/src/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/send_sp_payment_usecase.dart';
import 'package:silent/src/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:silent/src/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:silent/src/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/silent_server_status.dart';
import 'package:silent/src/domain/usecases/check_sp_server_status_usecase.dart';

export 'package:silent/src/domain/silent_server_status.dart'
    show SilentServerStatus;

// Part of the SP public surface: cross-feature consumers get these pure value
// objects (and the feature's failure family) via the facade, so they never
// import the feature's `domain/`.
export 'package:silent/src/domain/entities/sp_address.dart' show SilentAddress;
export 'package:silent/src/domain/entities/sp_address_kind.dart'
    show SilentAddressKind;
export 'package:silent/src/domain/entities/sp_balance.dart' show SilentBalance;
// The variants come with the sealed base on purpose: without them a consumer
// can neither switch exhaustively nor build one.
export 'package:silent/src/domain/entities/sp_recipient.dart'
    show SilentRecipient, SilentRecipientSp, SilentRecipientStandard;
export 'package:silent/src/domain/entities/sp_tx_draft.dart' show SilentTxDraft;
export 'package:silent/src/domain/entities/sp_update.dart'
    show
        SilentUpdate,
        SilentBalanceChanged,
        SilentSetupChanged,
        SilentChainTipChanged;
export 'package:silent/src/domain/entities/sp_wallet.dart' show SilentWallet;
// The sealed base plus every variant, so a consumer can switch on it
// exhaustively (AGENTS.md rule #11). Named one by one, never a blanket export:
// the list is the contract.
export 'package:silent/src/domain/silent_failure.dart'
    show
        SilentFailure,
        SilentRequiresSuperuser,
        SilentRequiresDevMode,
        SilentNotSetUp,
        SilentAlreadySetUp,
        SilentSessionBusy,
        SilentScanBusy,
        SilentSimulationDrifted,
        SilentBackendUnreachable,
        SilentConfigInvalid,
        SilentUnsupportedNetwork,
        SilentSetupCleanupFailed,
        SilentBackendRollbackFailed,
        SilentAmountBelowMinimum,
        SilentAmountExceedsBalance,
        SilentAddressNetworkMismatch,
        SilentInvalidAddress,
        SilentBroadcastUncertain,
        SilentUnexpected;

abstract interface class Silent {
  Future<Result<SilentServerStatus, SilentFailure>> checkServerStatus(
    BitcoinNetwork network,
  );
  Future<Result<bool, SilentFailure>> isFeatureEnabled();
  Future<Result<bool, SilentFailure>> isSetUp();
  bool get isScanning;
  Future<Result<SilentWallet?, SilentFailure>> refresh();
  Future<Result<void, SilentFailure>> revoke();
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates();
  Future<Result<void, SilentFailure>> syncWallet();
  Future<Result<BitcoinNetwork?, SilentFailure>> network();
  Future<Result<Sats, SilentFailure>> validateAmount(Sats amountSat);
  Future<Result<SilentRecipient, SilentFailure>> validateRecipient({
    required String input,
    required Sats amountSat,
    required bool isMax,
  });
  Future<Result<SilentTxDraft, SilentFailure>> preparePayment({
    required List<SilentRecipient> recipients,
    required BigInt feerateSatVb,
  });
  Future<Result<String, SilentFailure>> sendPayment({
    required SilentTxDraft draft,
  });
}

final class SilentCapability implements Silent {
  final CheckSpServerStatusUsecase _checkSpServerStatusUsecase;
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

  SilentCapability({
    required this._checkSpServerStatusUsecase,
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

  @override
  Future<Result<SilentServerStatus, SilentFailure>> checkServerStatus(
    BitcoinNetwork network,
  ) => _checkSpServerStatusUsecase.execute(network);

  /// Whether the SP feature is enabled (superuser + dev mode gate). Cross-feature
  /// consumers (the wallet) read the gate through here instead of the settings.
  @override
  Future<Result<bool, SilentFailure>> isFeatureEnabled() =>
      _getSpFeatureGateUsecase.check(allowUnconfigured: true);

  /// Whether the SP wallet is set up (gated + sentinel-aware). `Err` when the
  /// stored config or the revoke sentinel could not be read, so a failed read
  /// is never mistaken for "not set up".
  @override
  Future<Result<bool, SilentFailure>> isSetUp() =>
      _checkSpWalletSetupUsecase.execute();

  /// Synchronous view of [isSetUp], for the route gate, which cannot await.
  /// Refreshed by [isSetUp] and set directly by create and revoke.
  bool get isSetUpNow => _isSpSetUpNowUsecase.execute();

  /// Whether a scan is running (tracked in Dart, no FFI). Callers skip the
  /// wallet refresh while true so it never disposes the session mid-scan.
  @override
  bool get isScanning => _isSpScanningUsecase.execute();

  /// Reads a fresh snapshot from the live session without disposing it.
  /// `Ok(null)` when SP is not set up; `Err` on failure (e.g. a dispose still
  /// holds the inner lock) so the caller leaves its state intact and retries.
  ///
  /// No try/catch here on purpose: the adapter is the one boundary that turns
  /// a thrown FFI error into a failure (AGENTS.md rule #11), so the facade only
  /// forwards what the use case already returns.
  @override
  Future<Result<SilentWallet?, SilentFailure>> refresh() =>
      _getSpWalletUsecase.execute();

  /// Revoke the SP wallet (sentinel + on-disk delete + config delete). `Err`
  /// when the on-disk delete failed; the sentinel is already written so the
  /// wallet stays unloadable and the caller only surfaces a retry prompt.
  @override
  Future<Result<void, SilentFailure>> revoke() =>
      _revokeSpWalletUsecase.execute();

  /// Observe SP wallet changes (balance updates, setup created/revoked).
  @override
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates() =>
      _watchSpUpdatesUsecase.execute().transform(
        StreamTransformer.fromHandlers(
          handleData: (update, sink) => sink.add(Ok(update)),
          handleError: (error, stack, sink) {
            if (error is Error) {
              sink.addError(error, stack);
            } else {
              sink.add(
                const Err(SilentUnexpected('Silent update stream failed')),
              );
            }
          },
        ),
      );

  /// Run the SP side of an automatic sync tick: resume the chain scan when the
  /// wallet is close enough to the tip. `Ok(null)` when there is nothing to do;
  /// `Err` when the wallet read or the scan failed.
  @override
  Future<Result<void, SilentFailure>> syncWallet() =>
      _syncSpWalletUsecase.execute();

  /// The network the SP wallet runs on. `Ok(null)` when no session is live (a
  /// genuine unknown); `Err` on a read failure, so a caller can fail closed
  /// rather than assume mainnet.
  @override
  Future<Result<BitcoinNetwork?, SilentFailure>> network() async =>
      _getSpNetworkUsecase.execute();

  /// Up-front check that the amount is above zero and within the spendable
  /// balance. Rust `prepare()` stays the authority on fee-inclusive
  /// feasibility; this only blocks advancing on an obviously bad amount.
  @override
  Future<Result<Sats, SilentFailure>> validateAmount(Sats amountSat) async =>
      _validateSpAmountUsecase.execute(amountSat);

  @override
  Future<Result<SilentRecipient, SilentFailure>> validateRecipient({
    required String input,
    required Sats amountSat,
    required bool isMax,
  }) => _validateSpRecipientUsecase.execute(
    input: input,
    amountSat: amountSat,
    isMax: isMax,
  );

  @override
  Future<Result<SilentTxDraft, SilentFailure>> preparePayment({
    required List<SilentRecipient> recipients,
    required BigInt feerateSatVb,
  }) => _prepareSpPaymentUsecase.execute(
    recipients: recipients,
    feerateSatVb: feerateSatVb,
  );

  @override
  Future<Result<String, SilentFailure>> sendPayment({
    required SilentTxDraft draft,
  }) => _sendSpPaymentUsecase.execute(draft: draft);
}
