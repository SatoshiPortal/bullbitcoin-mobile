import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/clear_sp_scan_state_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/watchers/sp_notifications_watcher.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/set_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_sync_estimator.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/watchers/sp_header_retry_watcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin presentation cubit: transforms between UI state and SP use cases.
/// No FFI access, no orchestration; all of that lives in the application
/// layer behind the `SpAccountRepository` port.
class SpCubit extends Cubit<SpState> {
  final LoadSpWalletDataUsecase _loadSpWalletDataUsecase;
  final SpNotificationsWatcher _spNotificationsWatcher;
  final ScanSpWalletUsecase _scanSpWalletUsecase;
  final StopSpScanUsecase _stopSpScanUsecase;
  final ClearSpScanStateUsecase _clearSpScanStateUsecase;
  final RevokeSpWalletUsecase _revokeSpWalletUsecase;
  final GenerateTaprootAddressUsecase _generateTaprootAddressUsecase;
  final SetSpAutoScanUsecase _setSpAutoScanUsecase;
  final GetSpAutoScanUsecase _getSpAutoScanUsecase;

  StreamSubscription<SpNotification>? _notificationSub;
  final SpSyncEstimator _etaEstimator = SpSyncEstimator();

  // Synchronous re-entrancy guard for scan(). state.isScanning only flips true
  // on the ScanStarted notification, which arrives after scanOnce has already
  // spawned its background thread, so a double-tap in that window would slip
  // past the state check. This flag closes it at tap time.
  bool _scanInFlight = false;

  // The retry policy (attempts + backoff) lives in the watcher; the cubit only
  // reflects the outcome as a status.
  final SpHeaderRetryWatcher _headerRetryWatcher;

  SpCubit({
    required this._loadSpWalletDataUsecase,
    required this._spNotificationsWatcher,
    required this._scanSpWalletUsecase,
    required this._stopSpScanUsecase,
    required this._clearSpScanStateUsecase,
    required this._revokeSpWalletUsecase,
    required this._generateTaprootAddressUsecase,
    required this._setSpAutoScanUsecase,
    required this._headerRetryWatcher,
    required this._getSpAutoScanUsecase,
  }) : super(const SpState());

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _loadSpWalletDataUsecase.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isLoading: false,
            balance: value.wallet.balance,
            spAddress: value.wallet.spAddress,
            history: value.history,
            coins: value.coins,
            lastScannedHeight: value.wallet.lastScannedHeight,
            isScanning: value.wallet.isScanning,
            network: value.network,
            backendOnline: value.backendOnline,
            chainTip: value.chainTip,
            minBirthdayHeight: value.minBirthdayHeight,
            isAutoScanEnabled: _getSpAutoScanUsecase.execute(),
          ),
        );
        // A genuinely revoked wallet returns Err (below) and does not
        // re-subscribe, so the self-heal onDone cannot loop.
        _subscribeToNotifications();
      case Err(:final failure):
        log.warning('SpCubit.load: ${failure.logMessage}');
        emit(state.copyWith(isLoading: false, error: failure));
        if (failure is! SpNotSetUp &&
            failure is! SpRequiresSuperuser &&
            failure is! SpRequiresDevMode) {
          _subscribeToNotifications();
        }
    }
  }

  /// Reveal a fresh taproot receive address (explicit user action). Each call
  /// hands out a new never-before-issued address, never re-displays a prior
  /// one, so an address is never given to two payers.
  Future<void> generateTaprootAddress() async {
    if (isClosed) return;
    emit(state.copyWith(isGeneratingAddress: true, error: null));
    final result = await _generateTaprootAddressUsecase.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isGeneratingAddress: false,
            taprootReceiveAddress: value,
          ),
        );
      case Err(:final failure):
        log.warning('SpCubit.generateTaprootAddress: ${failure.logMessage}');
        emit(state.copyWith(isGeneratingAddress: false, error: failure));
    }
  }

  void _subscribeToNotifications() {
    unawaited(_notificationSub?.cancel());
    // The watcher owns the self-heal policy (re-establish + backoff + flap
    // cap); the cubit only maps events to state. On reconnect it reloads the
    // wallet data the new session exposes.
    _notificationSub = _spNotificationsWatcher
        .watch(onReconnect: () => unawaited(_refreshWalletData()))
        .listen(_onNotification);
  }

  void _onNotification(SpNotification n) {
    if (isClosed) return;
    switch (n) {
      case SpScanStarted(:final from, :final to):
        _onScanStarted(from, to);
      case SpScanReceiveProgress(:final current, :final end):
        _onScanReceiveProgress(current, end);
      case SpScanSpendProgress(:final current, :final end):
        _onScanSpendProgress(current, end);
      case SpScanCompleted():
        _onScanCompleted();
      case SpScanStopped():
        _onScanStopped();
      case SpScanFailed(:final failure):
        _onScanFailed(failure);
      case SpNewOutput():
      case SpOutputSpent():
      case SpElectrumTx():
      case SpBroadcasted():
        // Defer per-coin refreshes during a scan to avoid churn; the
        // ScanCompleted case refreshes once when the scan ends.
        if (!state.isScanning) unawaited(_refreshWalletData());
      case SpBroadcastFailed(:final message):
        log.warning('SpCubit.broadcast: broadcast failed: $message');
      case SpBackendOffline():
        emit(state.copyWith(backendOnline: false));
      case SpPaymentHistoryUpdated():
        unawaited(_refreshWalletData());
      case SpHeaderProgressStarted(:final phase, :final start, :final end):
        _onHeaderProgress(phase, from: start, current: start, to: end);
      case SpHeaderProgress(:final phase, :final current, :final end):
        _onHeaderProgress(
          phase,
          from: state.headerValidationFrom ?? current,
          current: current,
          to: end,
        );
      case SpHeaderProgressCompleted(:final phase):
        _onHeaderValidationCompleted(phase);
      case SpHeaderProgressFailed(:final phase):
        _onHeaderValidationFailed(phase);
    }
  }

  void _onScanStarted(int from, int to) {
    _etaEstimator.reset();
    emit(
      state.copyWith(
        isScanning: true,
        scanPhase: SpScanPhase.receive,
        scanStartTime: DateTime.now(),
        scanEtaSecs: null,
        scanLastDurationSecs: null,
        scanFrom: from,
        scanTo: to,
        scanCurrent: from,
      ),
    );
  }

  void _onScanReceiveProgress(int current, int end) {
    _etaEstimator.update(current, end, DateTime.now());
    emit(
      state.copyWith(
        scanPhase: SpScanPhase.receive,
        scanCurrent: current,
        scanTo: end,
        scanEtaSecs: _etaEstimator.estimateSecs(),
      ),
    );
  }

  void _onScanSpendProgress(int current, int end) {
    // First spend update: switch to step 2 and rebase the bar to the spend
    // range (its `current` is the spend start) so it runs 0 -> 100% again.
    final entering = state.scanPhase != SpScanPhase.spend;
    // The receive-phase EMA/samples describe a higher height range, so seed the
    // spend ETA from scratch instead of the wrong rate.
    if (entering) _etaEstimator.reset();
    _etaEstimator.update(current, end, DateTime.now());
    emit(
      state.copyWith(
        scanPhase: SpScanPhase.spend,
        scanFrom: entering ? current : state.scanFrom,
        scanCurrent: current,
        scanTo: end,
        scanEtaSecs: _etaEstimator.estimateSecs(),
      ),
    );
  }

  void _onScanCompleted() {
    // The one-shot scan runs on a background thread, so ScanCompleted is the
    // real done signal (scanOnce returned long before). Refresh here; the lock
    // is free between the scanner's per-block work, so the read does not block.
    final start = state.scanStartTime;
    emit(
      state.copyWith(
        isScanning: false,
        scanLastDurationSecs: start == null
            ? null
            : DateTime.now().difference(start).inSeconds,
      ),
    );
    unawaited(_refreshWalletData());
  }

  void _onScanStopped() {
    // Reload so lastScannedHeight reflects where the scan stopped; the next
    // scan resumes from there instead of restarting at the birthday.
    emit(state.copyWith(isScanning: false));
    unawaited(_refreshWalletData());
  }

  void _onScanFailed(SpFailure failure) {
    log.warning('SpCubit.scan: scan failed: ${failure.logMessage}');
    emit(state.copyWith(isScanning: false, error: failure));
    // A partial scan may still have updated the stores; refresh so the UI
    // reflects whatever landed before the failure (matches Completed/Stopped).
    unawaited(_refreshWalletData());
  }

  void _onHeaderProgress(
    SpHeaderValidationPhase phase, {
    required int from,
    required int current,
    required int to,
  }) {
    _resetHeaderRetry();
    emit(
      state.copyWith(
        headerValidationStatus: SpHeaderValidationStatus.validating,
        headerValidationPhase: phase,
        headerValidationFrom: from,
        headerValidationTo: to,
        headerValidationCurrent: current,
        chainTip: to,
      ),
    );
  }

  void _onHeaderValidationCompleted(SpHeaderValidationPhase phase) {
    _resetHeaderRetry();
    emit(
      state.copyWith(
        headerValidationStatus: SpHeaderValidationStatus.valid,
        headerValidationPhase: phase,
        headerValidationCurrent: state.headerValidationTo,
      ),
    );
  }

  /// A replay failure is always a bad stored chain, so it surfaces at once. An
  /// initial-sync failure is usually just a dropped connection, so it shows as
  /// reconnecting while the listener restart is retried.
  void _onHeaderValidationFailed(SpHeaderValidationPhase phase) {
    if (phase == SpHeaderValidationPhase.replay) {
      _resetHeaderRetry();
      emit(
        state.copyWith(
          headerValidationStatus: SpHeaderValidationStatus.failed,
          headerValidationPhase: phase,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        headerValidationStatus: SpHeaderValidationStatus.reconnecting,
        headerValidationPhase: phase,
      ),
    );
    _scheduleHeaderRetry(phase);
  }

  void _scheduleHeaderRetry(SpHeaderValidationPhase phase) {
    _headerRetryWatcher.start(
      onGaveUp: () {
        if (isClosed) return;
        emit(
          state.copyWith(
            headerValidationStatus: SpHeaderValidationStatus.failed,
            headerValidationPhase: phase,
          ),
        );
      },
    );
  }

  void _resetHeaderRetry() => _headerRetryWatcher.reset();

  /// Turn automatic scanning on or off. With it off nothing resumes a scan on
  /// its own and the nudge stays away, since the user asked to drive it.
  Future<void> setAutoScanEnabled({required bool isEnabled}) async {
    await _setSpAutoScanUsecase.execute(isEnabled: isEnabled);
    if (isClosed) return;
    emit(state.copyWith(isAutoScanEnabled: isEnabled));
  }

  Future<void> _refreshWalletData() async {
    final result = await _loadSpWalletDataUsecase.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            balance: value.wallet.balance,
            history: value.history,
            coins: value.coins,
            lastScannedHeight: value.wallet.lastScannedHeight,
            chainTip: value.chainTip,
            backendOnline: value.backendOnline,
          ),
        );
      // The wallet feature learns about this balance change independently, by
      // watching the SP repository's update stream (SpBalanceChanged). SP
      // does not push to the wallet bloc.
      case Err(:final failure):
        log.warning('SpCubit._refreshWalletData: ${failure.logMessage}');
    }
  }

  /// Eagerly reload balance/coins/history without touching the notification
  /// subscription. The send flow calls this after a broadcast for immediate
  /// spend feedback.
  Future<void> refresh() => _refreshWalletData();

  Future<void> scan({int? startHeight}) async {
    // Re-entrancy guard: two UI entry points plus a double-tap could invoke the
    // one-shot scan concurrently. Mirrors the send flow's isBroadcasting guard.
    if (_scanInFlight || state.isScanning) return;
    _scanInFlight = true;
    try {
      if (isClosed) return;
      emit(
        state.copyWith(
          isScanning: true,
          scanPhase: SpScanPhase.receive,
          scanStartTime: DateTime.now(),
          scanEtaSecs: null,
          scanLastDurationSecs: null,
          error: null,
        ),
      );
      // scanOnce returns immediately (the one-shot scan runs on a background
      // thread); progress + the post-scan refresh are driven by notifications.
      final result = await _scanSpWalletUsecase.execute(
        startHeight: startHeight,
      );
      if (isClosed) return;
      if (result case Err(:final failure)) {
        log.warning('SpCubit.scan: ${failure.logMessage}');
        if (failure is SpScanBusy) {
          emit(state.copyWith(error: failure));
        } else {
          emit(state.copyWith(isScanning: false, error: failure));
        }
      }
    } finally {
      // Only this call (which passed the guard) started the scan, so only this
      // call clears the flag.
      _scanInFlight = false;
    }
  }

  Future<void> stopScan() async {
    // Returns after flipping the cancel flag; the scan tears down
    // asynchronously and emits ScanStopped/ScanCompleted, at which point
    // `_onNotification` clears `state.isScanning`.
    if (await _stopSpScanUsecase.execute() case Err(:final failure)) {
      log.warning('SpCubit.stopScan: ${failure.logMessage}');
    }
  }

  Future<bool> clearScanState() async {
    if (isClosed || state.isScanning) return false;
    final result = await _clearSpScanStateUsecase.execute();
    if (isClosed) return false;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            error: null,
            lastScannedHeight: null,
            scanPhase: null,
            scanStartTime: null,
            scanEtaSecs: null,
            scanLastDurationSecs: null,
            scanFrom: null,
            scanTo: null,
            scanCurrent: null,
          ),
        );
        return true;
      case Err(:final failure):
        log.warning('SpCubit.clearScanState: ${failure.logMessage}');
        emit(state.copyWith(error: failure));
        return false;
    }
  }

  Future<bool> revokeWallet() async {
    if (isClosed) return false;
    emit(state.copyWith(isRevoking: true, error: null));
    if (await _revokeSpWalletUsecase.execute() case Err(:final failure)) {
      log.warning('SpCubit.revokeWallet: ${failure.logMessage}');
      if (isClosed) return false;
      emit(state.copyWith(isRevoking: false, error: failure));
      return false;
    }
    if (isClosed) return true;
    emit(state.copyWith(isRevoking: false));
    return true;
  }

  void clearError() {
    if (isClosed) return;
    emit(state.copyWith(error: null));
  }

  void dismissScanCaughtUp() {
    if (isClosed) return;
    emit(
      state.copyWith(
        scanPhase: null,
        scanStartTime: null,
        scanEtaSecs: null,
        scanLastDurationSecs: null,
        scanFrom: null,
        scanTo: null,
        scanCurrent: null,
      ),
    );
  }

  @override
  Future<void> close() async {
    _resetHeaderRetry();
    await _notificationSub?.cancel();
    await _spNotificationsWatcher.dispose();
    return super.close();
  }
}
