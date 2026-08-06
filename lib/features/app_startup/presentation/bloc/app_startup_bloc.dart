import 'dart:async';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/telemetry/recoverbull_telemetry_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
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
    required this._checkBackupUsecase,
    required this._isTorRequiredUsecase,
    required this._initTorUsecase,
    required this._recoverbullTelemetryCubit,
  }) : super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
    WidgetsBinding.instance.addObserver(this);
  }

  final ResetAppDataUsecase _resetAppDataUsecase;
  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final CheckForExistingDefaultWalletsUsecase
  _checkForExistingDefaultWalletsUsecase;
  final CheckLegacyInstallUsecase _checkLegacyInstallUsecase;
  final CheckBackupUsecase _checkBackupUsecase;
  final IsTorRequiredUsecase _isTorRequiredUsecase;
  final InitTorUsecase _initTorUsecase;
  final RecoverbullTelemetryCubit _recoverbullTelemetryCubit;

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

    try {
      // Log app version on startup
      final packageInfo = await PackageInfo.fromPlatform();
      log.info(
        'App started: ${packageInfo.appName} v${packageInfo.version}+${packageInfo.buildNumber}',
      );

      final doDefaultWalletsExist = await _checkForExistingDefaultWalletsUsecase
          .execute();

      // Pre-v5 ("BULL") installs are no longer migrated: gate them behind a
      // backup screen. Only when the new DB is empty — the legacy marker can
      // survive a failed migration while the user has since set up working
      // v5+ wallets, and those current seeds are not legacy-format: gating
      // such an install would show a backup screen missing its live wallets
      // and instruct deleting them.
      if (!doDefaultWalletsExist &&
          await _checkLegacyInstallUsecase.execute()) {
        log.warning('Legacy (pre-v5) install detected — backup gate shown');
        emit(const AppStartupState.legacyBackupRequired());
        return;
      }

      bool isPinCodeSet = false;

      if (doDefaultWalletsExist) {
        isPinCodeSet = switch (await _checkPinCodeExistsUsecase.execute()) {
          Ok(:final value) => value,
          Err(:final failure) => throw failure,
        };
        // Other startup logic can be added here, e.g. payjoin sessions resume
      } else {
        // This is a fresh install, so reset the app data that might still be
        //  there from a previous install.
        //  (e.g. secure storage data on iOS like the pin code)
        await _resetAppDataUsecase.execute();
      }

      // Run Tor initialization in background
      try {
        final isTorRequired = await _isTorRequiredUsecase.execute();
        if (isTorRequired) unawaited(_initTorUsecase.execute());
      } catch (e) {
        log.severe(
          message: 'Tor initialization check failed',
          error: e,
          trace: StackTrace.current,
        );
      }

      // Brute-force telemetry check: cold launch only, unawaited, never
      // blocking startup. The cubit is a no-op when the feature flag is
      // off, when Tor is not ready, or when the last check is still fresh.
      unawaited(_recoverbullTelemetryCubit.checkOnColdLaunch());

      emit(
        AppStartupState.success(
          isPinCodeSet: isPinCodeSet,
          hasDefaultWallets: doDefaultWalletsExist,
        ),
      );
    } on KeychainLockedException catch (_) {
      // iOS pre-first-unlock pre-warm: the keychain is locked, so any
      // seed read (CheckForExistingDefaultWalletsUsecase →
      // _seedRepository.get) throws this typed exception. DO NOT emit
      // failure — that renders the "Contact support" / "App Startup
      // Error" screen and leaves the user permanently stuck on it once
      // they actually open the app post-unlock (the pre-warmed engine
      // is reused, so the failure state survives until the next cold
      // launch). Instead stay in `loadingInProgress` (OnboardingSplash)
      // and arm `_awaitingKeychainUnlock`; `didChangeAppLifecycleState`
      // re-dispatches `AppStartupStarted` on `resumed`, which only
      // fires after the user has unlocked the device since boot.
      _awaitingKeychainUnlock = true;
      log.warning(
        'App startup blocked on keychain (device not unlocked since '
        'boot) — staying on splash, will retry on lifecycle resumed',
      );
    } catch (e) {
      bool hasBackup;
      try {
        // Check if there is a backup available
        hasBackup = await _checkBackupUsecase.execute();
      } catch (_) {
        log.severe(
          message: 'Failed to check for backup availability during app startup',
          error: e,
          trace: StackTrace.current,
        );
        hasBackup = false;
      }
      emit(AppStartupState.failure(e, hasBackup: hasBackup));
    }
  }
}
