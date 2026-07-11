import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_sync_estimator.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin presentation cubit: transforms between UI state and SP use cases.
/// No FFI access, no orchestration; all of that lives in the application
/// layer behind the `SpAccountRepository` port.
class SpCubit extends Cubit<SpState> {
  final LoadSpWalletDataUsecase _loadSpWalletDataUsecase;
  final WatchSpNotificationsUsecase _watchSpNotificationsUsecase;
  final ScanSpWalletUsecase _scanSpWalletUsecase;
  final StopSpScanUsecase _stopSpScanUsecase;
  final RevokeSpWalletUsecase _revokeSpWalletUsecase;
  final GenerateTaprootAddressUsecase _generateTaprootAddressUsecase;

  StreamSubscription<SpNotification>? _notificationSub;
  final SpSyncEstimator _etaEstimator = SpSyncEstimator();

  // Synchronous re-entrancy guard for scan(). state.isScanning only flips true
  // on the ScanStarted notification, which arrives after scanOnce has already
  // spawned its background thread, so a double-tap in that window would slip
  // past the state check. This flag closes it at tap time.
  bool _scanInFlight = false;

  // Guards against a flapping session busy-looping the self-heal: a stream that
  // completes right after each re-establish would otherwise re-subscribe with no
  // delay or bound. A recycle after a healthy stretch stays immediate.
  Timer? _resubscribeTimer;
  int _rapidResubscribes = 0;
  DateTime? _lastResubscribeAt;
  static const int _maxRapidResubscribes = 5;
  static const Duration _resubscribeBackoff = Duration(seconds: 2);
  static const Duration _resubscribeHealthyGap = Duration(seconds: 30);

  SpCubit({
    required this._loadSpWalletDataUsecase,
    required this._watchSpNotificationsUsecase,
    required this._scanSpWalletUsecase,
    required this._stopSpScanUsecase,
    required this._revokeSpWalletUsecase,
    required this._generateTaprootAddressUsecase,
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
          ),
        );
        // A genuinely revoked wallet returns Err (below) and does not
        // re-subscribe, so the self-heal onDone cannot loop.
        _subscribeToNotifications();
      case Err(:final failure):
        log.warning('SpCubit.load: ${failure.logMessage}');
        emit(state.copyWith(isLoading: false, error: failure));
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
    try {
      unawaited(_notificationSub?.cancel());
      _notificationSub = _watchSpNotificationsUsecase.execute().listen(
        _onNotification,
        // The singleton session can be recycled out from under us (a wallet-
        // side full refresh after a network change disposes it). When that
        // closes the notification stream, re-establish + re-subscribe via
        // load() instead of leaving a dead screen. A genuinely revoked wallet
        // makes load() emit an error and not re-subscribe, so this can't loop.
        onDone: _reestablishSession,
        onError: (Object e) {
          log.warning('SpCubit: notification stream error: $e');
          _reestablishSession();
        },
      );
    } catch (e) {
      log.warning('SpCubit: notification subscribe failed: $e');
    }
  }

  void _reestablishSession() {
    if (isClosed) return;
    final now = DateTime.now();
    final previous = _lastResubscribeAt;
    _lastResubscribeAt = now;
    // A recycle after a healthy stretch (e.g. a network-change dispose) is a
    // one-off: re-establish at once and forget earlier attempts.
    if (previous == null || now.difference(previous) > _resubscribeHealthyGap) {
      _rapidResubscribes = 0;
      unawaited(load());
      return;
    }
    // Rapid repeats mean the backend is flapping. Cap the attempts and space
    // them out so a stream that closes right after every re-establish can't
    // busy-loop.
    _rapidResubscribes++;
    if (_rapidResubscribes > _maxRapidResubscribes) {
      log.warning(
        'SpCubit: notification stream flapping; stopped re-subscribing',
      );
      return;
    }
    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(_resubscribeBackoff, () {
      if (isClosed) return;
      unawaited(load());
    });
  }

  void _onNotification(SpNotification n) {
    if (isClosed) return;
    switch (n) {
      case SpScanStarted(:final from, :final to):
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
      case SpScanReceiveProgress(:final current, :final end):
        _etaEstimator.update(current, end, DateTime.now());
        emit(
          state.copyWith(
            scanPhase: SpScanPhase.receive,
            scanCurrent: current,
            scanTo: end,
            scanEtaSecs: _etaEstimator.estimateSecs(),
          ),
        );
      case SpScanSpendProgress(:final current, :final end):
        // First spend update: switch to step 2 and rebase the bar to the spend
        // range (its `current` is the spend start) so it runs 0 -> 100% again.
        final entering = state.scanPhase != SpScanPhase.spend;
        // The receive-phase EMA/samples describe a higher height range, so seed
        // the spend ETA from scratch instead of the wrong rate.
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
      case SpScanCompleted():
        // The one-shot scan runs on a background thread, so ScanCompleted is the
        // real done signal (scanOnce returned long before). Refresh here; the
        // lock is free between the scanner's per-block work, so the read does
        // not block.
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
      case SpScanStopped():
        // Reload so lastScannedHeight reflects where the scan stopped; the next
        // scan resumes from there instead of restarting at the birthday.
        emit(state.copyWith(isScanning: false));
        unawaited(_refreshWalletData());
      case SpScanFailed(:final message):
        // bwk reports the failure as a raw string; keep it for logs only and
        // show the generic message.
        emit(
          state.copyWith(
            isScanning: false,
            error: SpUnexpected('SP scan failed: $message'),
          ),
        );
        // A partial scan may still have updated the stores; refresh so the UI
        // reflects whatever landed before the failure (matches Completed/Stopped).
        unawaited(_refreshWalletData());
      case SpNewOutput():
      case SpOutputSpent():
      case SpElectrumTx():
        // Defer per-coin refreshes during a scan to avoid churn; the
        // ScanCompleted case refreshes once when the scan ends.
        if (!state.isScanning) unawaited(_refreshWalletData());
      case SpBackendOffline():
        emit(state.copyWith(backendOnline: false));
    }
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
      emit(state.copyWith(error: null));
      // scanOnce returns immediately (the one-shot scan runs on a background
      // thread); progress + the post-scan refresh are driven by notifications.
      final result = await _scanSpWalletUsecase.execute(startHeight: startHeight);
      if (isClosed) return;
      if (result case Err(:final failure)) {
        log.warning('SpCubit.scan: ${failure.logMessage}');
        // A SpScanBusy means a scan the guard did not catch is live; clearing
        // isScanning would wedge the Stop button, so leave it untouched.
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
    try {
      await _stopSpScanUsecase.execute();
    } catch (e) {
      log.warning('SpCubit.stopScan: $e');
    }
  }

  Future<void> revokeWallet() async {
    // The usecase writes the `.revoked` sentinel and notifies observers even on
    // its dir-delete failure path, so the wallet is already unloadable. Ignore
    // a failure here so the UI always navigates away instead of getting stuck.
    if (await _revokeSpWalletUsecase.execute() case Err(:final failure)) {
      log.warning('SpCubit.revokeWallet: ${failure.logMessage}');
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  @override
  Future<void> close() async {
    _resubscribeTimer?.cancel();
    await _notificationSub?.cancel();
    return super.close();
  }
}
