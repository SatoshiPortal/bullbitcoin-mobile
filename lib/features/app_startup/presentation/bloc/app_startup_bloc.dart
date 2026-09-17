import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'app_startup_bloc.freezed.dart';
part 'app_startup_event.dart';
part 'app_startup_state.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState>
    with WidgetsBindingObserver {
  AppStartupBloc({
    required this._resetAppDataUsecase,
    required this._checkPinCodeExistsUsecase,
    required this._checkForExistingDefaultWalletsUsecase,
    required this._checkLegacyInstallUsecase,
    required this._initializeRequiredTorUsecase,
  }) : super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
    WidgetsBinding.instance.addObserver(this);
  }

  final ResetAppDataUsecase _resetAppDataUsecase;
  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final CheckForExistingDefaultWalletsUsecase
  _checkForExistingDefaultWalletsUsecase;
  final CheckLegacyInstallUsecase _checkLegacyInstallUsecase;
  final InitializeRequiredTorUsecase _initializeRequiredTorUsecase;

  /// True while we're sitting on the splash because a startup step
  /// threw `KeychainLockedException` (iOS pre-first-unlock pre-warm).
  /// Cleared by `didChangeAppLifecycleState(resumed)`, which re-fires
  /// `AppStartupStarted` so init can retry on a now-unlocked keychain.
  bool _awaitingKeychainUnlock = false;

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingKeychainUnlock) {
      _awaitingKeychainUnlock = false;
      log.fine('App resumed — retrying startup after keychain unlock');
      add(const AppStartupStarted());
    }
  }

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupState.loadingInProgress());

    await _logAppVersion();

    final bool doDefaultWalletsExist;
    switch (await _checkForExistingDefaultWalletsUsecase.execute()) {
      case Ok(:final value):
        doDefaultWalletsExist = value;
      case Err(failure: AppStartupKeychainLockedFailure()):
        _waitForKeychainUnlock();
        return;
      case Err(:final failure):
        emit(AppStartupState.failure(failure));
        return;
    }

    // Pre-v5 ("BULL") installs are no longer migrated: gate them behind a
    // backup screen. Only when the new DB is empty — the legacy marker can
    // survive a failed migration while the user has since set up working
    // v5+ wallets, and those current seeds are not legacy-format: gating
    // such an install would show a backup screen missing its live wallets
    // and instruct deleting them.
    if (!doDefaultWalletsExist) {
      switch (await _checkLegacyInstallUsecase.execute()) {
        case Ok(value: true):
          log.warning('Legacy (pre-v5) install detected — backup gate shown');
          emit(const AppStartupState.legacyBackupRequired());
          return;
        case Ok():
          break;
        case Err(failure: AppStartupKeychainLockedFailure()):
          _waitForKeychainUnlock();
          return;
        case Err(:final failure):
          emit(AppStartupState.failure(failure));
          return;
      }
    }

    bool isPinCodeSet = false;

    if (doDefaultWalletsExist) {
      switch (await _checkPinCodeExistsUsecase.execute()) {
        case Ok(:final value):
          isPinCodeSet = value;
        case Err(failure: AppUnlockKeychainLockedFailure()):
          _waitForKeychainUnlock();
          return;
        case Err(:final failure):
          log.severe(
            message: 'PIN check failed at startup',
            error: failure,
            trace: StackTrace.current,
          );
          emit(const AppStartupState.failure(AppStartupPinCheckFailure()));
          return;
      }
      // Other startup logic can be added here, e.g. payjoin sessions resume
    } else {
      // This is a fresh install, so reset the app data that might still be
      //  there from a previous install.
      //  (e.g. secure storage data on iOS like the pin code)
      switch (await _resetAppDataUsecase.execute()) {
        case Ok():
          break;
        case Err(failure: AppStartupKeychainLockedFailure()):
          // Same retry path as every other keychain read. Emitting failure
          //  here would strand a pre-first-unlock launch on the error screen
          //  for the sake of a cleanup step that can simply run later.
          _waitForKeychainUnlock();
          return;
        case Err(:final failure):
          // Not ignored: a stale PIN surviving here is read on the NEXT
          //  launch once wallets exist, locking the user out with a PIN they
          //  never set.
          emit(AppStartupState.failure(failure));
          return;
      }
    }

    // Warm the embedded client without delaying the startup screen. The
    // coordinator makes this single-flight with any concurrent consumer.
    unawaited(_initializeTorInBackground());

    emit(
      AppStartupState.success(
        isPinCodeSet: isPinCodeSet,
        hasDefaultWallets: doDefaultWalletsExist,
      ),
    );
  }

  /// Holds the splash and arms a retry instead of failing.
  ///
  /// iOS pre-first-unlock pre-warm: the keychain is locked, so any seed read
  /// (CheckForExistingDefaultWalletsUsecase -> _seedRepository.get) fails.
  /// DO NOT emit failure — that renders the "Contact support" / "App Startup
  /// Error" screen and leaves the user permanently stuck on it once they
  /// actually open the app post-unlock (the pre-warmed engine is reused, so
  /// the failure state survives until the next cold launch). Instead stay in
  /// `loadingInProgress` (OnboardingSplash) and arm
  /// `_awaitingKeychainUnlock`; `didChangeAppLifecycleState` re-dispatches
  /// `AppStartupStarted` on `resumed`, which only fires after the user has
  /// unlocked the device since boot.
  void _waitForKeychainUnlock() {
    _awaitingKeychainUnlock = true;
    log.warning(
      'App startup blocked on keychain (device not unlocked since '
      'boot) — staying on splash, will retry on lifecycle resumed',
    );
  }

  /// Diagnostic only. A platform-channel failure here must never block
  /// startup — the app works fine without knowing its own version string —
  /// so it is caught rather than modelled as a failure.
  ///
  /// Still awaited, unlike [_initializeTorInBackground]: it is what puts the
  /// version at the top of a startup log, and detaching it would let later
  /// lines overtake it. The catch is what makes awaiting safe; before this
  /// change the same call was awaited under the handler's outer try.
  Future<void> _logAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      log.info(
        'App started: ${info.appName} v${info.version}+${info.buildNumber}',
      );
    } on Object catch (e, st) {
      log.warning('Could not read package info', error: e, trace: st);
    }
  }

  Future<void> _initializeTorInBackground() async {
    try {
      await _initializeRequiredTorUsecase.execute();
    } catch (error, stackTrace) {
      log.severe(
        message: 'Required Tor initialization failed',
        error: error,
        trace: stackTrace,
      );
    }
  }
}
