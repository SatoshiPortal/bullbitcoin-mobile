import 'dart:async';

import '../domain/exchange_access.dart';

import 'package:exchange/exchange.dart';

import '../domain/usecases/get_exchange_account_usecase.dart';
import '../domain/usecases/get_exchange_announcements_usecase.dart';
import '../domain/usecases/save_exchange_preferences_usecase.dart';
import '../domain/usecases/complete_exchange_authentication_usecase.dart';
import '../domain/usecases/delete_exchange_account_usecase.dart';
import '../domain/usecases/enable_exchange_usecase.dart';
import '../domain/usecases/resolve_exchange_access_usecase.dart';
import '../domain/usecases/sign_out_exchange_usecase.dart';
import '../domain/usecases/watch_exchange_access_usecase.dart';
import '../domain/usecases/watch_exchange_notifications_usecase.dart';
import 'exchange_state.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

export '../domain/usecases/delete_exchange_account_usecase.dart'
    show ExchangeAccountDeletionOutcome;

/// Presents account data and forwards access operations to their use cases.
class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required GetExchangeAccountUsecase getExchangeAccountUsecase,
    required SaveExchangePreferencesUsecase saveExchangePreferencesUsecase,
    required GetExchangeAnnouncementsUsecase getExchangeAnnouncementsUsecase,
    required this._deleteAccount,
    required this._enableAccess,
    required this._resolveAccess,
    required this._signOut,
    required WatchExchangeAccessUsecase watchAccess,
    required WatchExchangeNotificationsUsecase
    watchExchangeNotificationsUsecase,
  }) : _getAccount = getExchangeAccountUsecase,
       _savePreferences = saveExchangePreferencesUsecase,
       _getAnnouncements = getExchangeAnnouncementsUsecase,
       _watchAccess = watchAccess,
       _watchNotifications = watchExchangeNotificationsUsecase,
       super(const ExchangeState()) {
    _notifications = _watchNotifications.accountChanges().listen(
      (_) => fetchUserSummary(),
    );
    _access = watchAccess.execute().listen((access) {
      if (isClosed) return;
      if (access case ExchangeAccessEnabled(
        session: ExchangeAccessSession.signedIn,
      )) {
        // Reconciliation disconnects before it emits signed in, and an
        // unchanged account emits no summary transition to reopen the socket.
        unawaited(fetchUserSummary());
        unawaited(connectWebSocket());
      } else {
        _accountAttempt++;
        emit(const ExchangeState());
      }
    });
  }
  final WatchExchangeAccessUsecase _watchAccess;
  final GetExchangeAccountUsecase _getAccount;
  final SaveExchangePreferencesUsecase _savePreferences;
  final GetExchangeAnnouncementsUsecase _getAnnouncements;
  final DeleteExchangeAccountUsecase _deleteAccount;
  final EnableExchangeUsecase _enableAccess;
  final ResolveExchangeAccessUsecase _resolveAccess;
  final SignOutExchangeUsecase _signOut;
  final WatchExchangeNotificationsUsecase _watchNotifications;
  StreamSubscription<Object?>? _notifications;
  StreamSubscription<ExchangeAccess>? _access;
  int _accountAttempt = 0;

  Future<void> fetchUserSummary() async {
    if (isClosed) return;
    final attempt = ++_accountAttempt;
    if (state.getUserSummaryFailure != null) {
      emit(state.copyWith(getUserSummaryFailure: null));
    }
    final result = await _getAccount.execute();
    if (isClosed ||
        attempt != _accountAttempt ||
        _watchAccess.current is! ExchangeAccessEnabled ||
        (_watchAccess.current as ExchangeAccessEnabled).session !=
            ExchangeAccessSession.signedIn) {
      return;
    }
    switch (result) {
      case Err(failure: ExchangeOperationStaleFailure()):
        return;
      case Err(failure: ExchangeUnsupportedNetworkFailure()):
        emit(
          state.copyWith(
            userSummary: null,
            announcements: [],
            getUserSummaryFailure: const ExchangeUnsupportedNetworkFailure(),
          ),
        );
        return;
      case Err(:final failure):
        emit(state.copyWith(getUserSummaryFailure: failure));
      case Ok(:final value):
        emit(state.copyWith(userSummary: value, getUserSummaryFailure: null));
        unawaited(loadAnnouncements());
    }
  }

  Future<void> stopDca() async {
    emit(state.copyWith(isSaving: true, stopDcaFailure: null));
    final result = await _savePreferences.execute(dcaEnabled: false);
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(state.copyWith(isSaving: false, stopDcaFailure: failure));
      return;
    }
    await fetchUserSummary();
    if (!isClosed) emit(state.copyWith(isSaving: false));
  }

  /// Saves the WebView session as an API key, then loads the account.
  Future<Result<void, ExchangeFailure>> completeAuthentication(
    CompleteExchangeAuthenticationUsecase authentication, {
    required bool Function() isCurrent,
  }) async {
    final result = await authentication.execute(
      isCurrent: () => !isClosed && isCurrent(),
    );
    if (result is Ok && !isClosed && isCurrent()) await fetchUserSummary();
    return result;
  }

  /// Support may prepare access even where trading is restricted.
  Future<Result<void, ExchangeFailure>> enableForSupport() =>
      _enableAccess.execute(forSupport: true);

  /// Explicit sign-out; access stays off until the user enables it again.
  Future<Result<void, ExchangeFailure>> logout() => _signOut.execute();

  Future<void> retryAccess() async {
    final _ = await _resolveAccess.execute();
  }

  void clearStopDcaFailure() => emit(state.copyWith(stopDcaFailure: null));
  Future<Result<ExchangeAccountDeletionOutcome, ExchangeFailure>>
  deleteAccount() => _deleteAccount.execute();
  Future<void> loadAnnouncements() async {
    if (isClosed || !state.hasUser) return;
    final result = await _getAnnouncements.execute();
    if (isClosed || !state.hasUser) return;
    if (result case Err(failure: ExchangeOperationStaleFailure())) return;
    emit(
      state.copyWith(
        announcements: switch (result) {
          Ok(:final value) => value,
          Err() => const [],
        },
        loadingAnnouncements: false,
      ),
    );
  }

  Future<void> connectWebSocket() async {
    final _ = await _watchNotifications.connect();
  }

  Future<void> reconnectWebSocket() async {
    final _ = await _watchNotifications.reconnect();
  }

  void disconnectWebSocket() => _watchNotifications.disconnect();
  @override
  Future<void> close() async {
    await _notifications?.cancel();
    await _access?.cancel();
    _watchNotifications.disconnect();
    return super.close();
  }
}
