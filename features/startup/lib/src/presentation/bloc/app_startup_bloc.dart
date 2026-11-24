import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:startup/src/domain/app_startup_failure.dart';
import 'package:startup/src/domain/usecases/prepare_wallet_startup_usecase.dart';
import 'package:startup/src/domain/usecases/restore_missing_default_secret_usecase.dart';
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
    required this._prepareWalletStartup,
    required this._restoreMissingDefaultSecretUsecase,
  }) : super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
    on<AppStartupUnlocked>(_onAppStartupUnlocked);
    WidgetsBinding.instance.addObserver(this);
  }

  final PrepareWalletStartupUsecase _prepareWalletStartup;
  final RestoreMissingDefaultSecretUsecase _restoreMissingDefaultSecretUsecase;

  /// Stores the recovery phrase of a default wallet whose secret is missing,
  /// then starts the app again. The words go straight to the use case and are
  /// never held in state; the result is returned so the entry screen can say
  /// why a phrase was refused.
  Future<Result<void, AppStartupFailure>> restoreDefaultSecret(
    List<String> words, {
    required Language language,
    String passphrase = '',
  }) async {
    final failure = switch (state) {
      AppStartupFailureState(
        :final AppStartupMissingDefaultSecretFailure failure,
      ) =>
        failure,
      _ => null,
    };
    if (failure == null) {
      return const Err(AppStartupRestoreFailure('no missing secret'));
    }
    final result = await _restoreMissingDefaultSecretUsecase.execute(
      expectedFingerprint: failure.masterFingerprint,
      expectedWalletId: failure.walletId,
      words: words,
      language: language,
      passphrase: passphrase,
    );
    if (result is Ok) add(const AppStartupStarted());
    return result;
  }

  /// True while we're sitting on the splash because a startup step
  /// threw `KeychainLockedException` (iOS pre-first-unlock pre-warm).
  /// Cleared by `didChangeAppLifecycleState(resumed)`, which re-fires
  /// `AppStartupStarted` so init can retry on a now-unlocked keychain.
  bool _awaitingKeychainUnlock = false;
  bool _authenticated = false;

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

    switch (await _prepareWalletStartup.execute(
      authenticated: _authenticated,
    )) {
      case Ok(:final value):
        emit(
          AppStartupState.success(
            isPinCodeSet: value.requiresPin,
            hasDefaultWallets: value.hasDefaultWallets,
          ),
        );
      case Err(failure: AppStartupKeychainLockedFailure()):
        _waitForKeychainUnlock();
      case Err(:final failure):
        emit(AppStartupState.failure(failure));
    }
  }

  Future<void> _onAppStartupUnlocked(
    AppStartupUnlocked event,
    Emitter<AppStartupState> emit,
  ) async {
    _authenticated = true;
    await _onAppStartupStarted(const AppStartupStarted(), emit);
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
  /// Still awaited, unlike Tor warmup: it is what puts the
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
}
