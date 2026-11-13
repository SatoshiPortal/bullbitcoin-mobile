import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_session.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/clear_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ExchangeAccountDeletionOutcome { completed, stale }

class ExchangeCubit extends Cubit<ExchangeState> {
  final GetExchangeAccountUsecase _getExchangeAccountUsecase;
  final SaveExchangePreferencesUsecase _saveExchangePreferencesUsecase;
  final ClearExchangeSessionUsecase _clearExchangeSessionUsecase;
  final GetExchangeAnnouncementsUsecase _getExchangeAnnouncementsUsecase;
  final RequestExchangeAccountDeletionUsecase
  _requestExchangeAccountDeletionUsecase;
  final WatchExchangeNotificationsUsecase _watchExchangeNotificationsUsecase;

  final ExchangeAccessFacade? _access;
  final ExchangeSession? _sessionFacts;
  final Set<Future<Result<void, ExchangeFailure>>> _authenticationsInFlight =
      {};
  Future<ExchangeFailure?>? _logoutInFlight;
  final Set<Future<Result<void, ExchangeFailure>>> _socketOperations = {};
  StreamSubscription<NotificationMessage>? _notificationSubscription;
  // Late results must belong to the current session and request.
  Object _session = Object();
  Object? _authenticationAttempt;
  Object? _accountAttempt;

  ExchangeCubit({
    required this._getExchangeAccountUsecase,
    required this._saveExchangePreferencesUsecase,
    required this._clearExchangeSessionUsecase,
    required this._getExchangeAnnouncementsUsecase,
    required this._requestExchangeAccountDeletionUsecase,
    required this._watchExchangeNotificationsUsecase,
    this._access,
    this._sessionFacts,
  }) : super(const ExchangeState()) {
    _notificationSubscription = _watchExchangeNotificationsUsecase
        .accountChanges()
        .listen((_) => fetchUserSummary());
  }

  /// Best-effort: the socket failure is logged at the repository boundary and
  /// deliberately not surfaced — the exchange works without notifications.
  bool get _accountAllowed =>
      _access == null || _access.current.canUseAuthenticatedExchange;

  Future<void> connectWebSocket() async {
    if (!_accountAllowed) return;
    // Result deliberately discarded: logged at the repository boundary.
    final operation = _watchExchangeNotificationsUsecase.connect();
    _socketOperations.add(operation);
    final _ = await operation;
    _socketOperations.remove(operation);
    if (!_accountAllowed || _logoutInFlight != null) disconnectWebSocket();
  }

  void disconnectWebSocket() => _watchExchangeNotificationsUsecase.disconnect();

  void suspendSession({bool clearAccount = false}) {
    _authenticationAttempt = null;
    _accountAttempt = null;
    _session = Object();
    _sessionFacts?.invalidate();
    disconnectWebSocket();
    if (clearAccount && !isClosed) emit(const ExchangeState());
  }

  /// Call this when the network environment changes to reconnect to the
  /// correct WebSocket.
  Future<void> reconnectWebSocket() async {
    if (!_accountAllowed) {
      disconnectWebSocket();
      return;
    }
    final operation = _watchExchangeNotificationsUsecase.reconnect();
    _socketOperations.add(operation);
    final _ = await operation;
    _socketOperations.remove(operation);
    if (!_accountAllowed || _logoutInFlight != null) disconnectWebSocket();
  }

  Future<void> fetchUserSummary() async {
    if (isClosed || !_accountAllowed) return;
    final session = _session;
    final accessGeneration = _access?.generation;
    final attempt = Object();
    _accountAttempt = attempt;
    emit(state.copyWith(getUserSummaryFailure: null));

    final result = await _getExchangeAccountUsecase.execute();
    if (isClosed ||
        !identical(_session, session) ||
        !identical(_accountAttempt, attempt) ||
        (_access != null && _access.generation != accessGeneration)) {
      return;
    }

    switch (result) {
      case Err(:final failure):
        if (failure is ExchangeNotAuthenticatedFailure) {
          // Close capabilities immediately; the durable disable journal is
          // written before deleting the scoped credential and cookies.
          _access?.suspend();
          _sessionFacts?.publish(ExchangeSessionStatus.expired);
          emit(
            state.copyWith(userSummary: null, getUserSummaryFailure: failure),
          );
          await _endSession(expired: true);
          return;
        }
        if (failure is ExchangeNetworkFailure) {
          final access = _access;
          if (access != null) {
            final _ = await access.reconcileSession(
              ExchangeSessionFact.networkUnavailable,
              generation: accessGeneration,
            );
            if (isClosed ||
                !identical(_session, session) ||
                !identical(_accountAttempt, attempt) ||
                access.generation != accessGeneration) {
              return;
            }
          }
        }
        emit(state.copyWith(getUserSummaryFailure: failure));
        return;
      case Ok(:final value):
        emit(state.copyWith(userSummary: value));
    }

    // Not awaited: the banner is decorative, and callers that await this
    // (login, stopDca) must not wait on it.
    unawaited(loadAnnouncements());
  }

  /// The operation is scoped to its WebView and is never retained in state.
  Future<ExchangeFailure?> completeAuthentication(
    CompleteExchangeAuthenticationUsecase operation,
  ) async {
    if (isClosed ||
        _logoutInFlight != null ||
        _access?.current.transition == ExchangeAccessTransition.disabling) {
      return const ExchangeAuthenticationFailure();
    }
    final attempt = Object();
    _authenticationAttempt = attempt;
    final accessGeneration = _access?.generation;
    final pending = operation.execute(
      isCurrent: () => !isClosed && identical(_authenticationAttempt, attempt),
    );
    _authenticationsInFlight.add(pending);
    final result = await pending;
    _authenticationsInFlight.remove(pending);
    if (isClosed || !identical(_authenticationAttempt, attempt)) return null;
    if (result case Err(:final failure)) {
      _authenticationAttempt = null;
      return failure;
    }
    final reconciled = await _access?.reconcileSession(
      ExchangeSessionFact.authenticated,
      generation: accessGeneration,
    );
    if (isClosed || !identical(_authenticationAttempt, attempt)) return null;
    if (reconciled case Err()) return const ExchangeApiKeyStorageFailure();
    if (reconciled case Ok(value: ExchangeAccessOutcome.stale)) return null;
    _authenticationAttempt = null;
    _sessionFacts?.publish(ExchangeSessionStatus.authenticated);
    _session = Object();
    emit(const ExchangeState());
    await fetchUserSummary();
    return null;
  }

  void clearStopDcaFailure() {
    emit(state.copyWith(stopDcaFailure: null));
  }

  Future<void> stopDca() async {
    if (isClosed || !_accountAllowed) return;
    final session = _session;
    emit(state.copyWith(isSaving: true, stopDcaFailure: null));

    // The use-case reads a fresh summary and fills the rest of the
    // preference set; the DCA flag is the only field this call changes.
    final result = await _saveExchangePreferencesUsecase.execute(
      dcaEnabled: false,
    );
    if (isClosed || !identical(_session, session)) return;

    if (result case Err(:final failure)) {
      // Surfaced, not swallowed: otherwise the tile silently keeps saying the
      // recurring buy is active and the user has no idea the stop failed.
      emit(state.copyWith(isSaving: false, stopDcaFailure: failure));
      return;
    }

    // Refresh so the tile reflects whatever the server actually holds rather
    // than what we hoped it would hold.
    await fetchUserSummary();
    if (isClosed || !identical(_session, session)) return;

    emit(state.copyWith(isSaving: false));
  }

  /// Returns the failure when the session could not be cleared.
  ///
  /// Local state is NOT cleared in that case, and that is deliberate: if the
  /// stored API key survives, showing a signed-out UI would be a lie — the
  /// next `fetchUserSummary` (app restart, notification refresh) would sign
  /// the user straight back in. On a shared device that is the difference
  /// between believing the session is gone and it still being live.
  Future<ExchangeFailure?> logout() => _endSession();

  Future<ExchangeFailure?> _endSession({bool expired = false}) {
    final running = _logoutInFlight;
    if (running != null) return running;
    final operation = _logout(
      expired: expired,
    ).whenComplete(() => _logoutInFlight = null);
    _logoutInFlight = operation;
    return operation;
  }

  Future<ExchangeFailure?> _logout({required bool expired}) async {
    if (isClosed) return null;
    _authenticationAttempt = null;
    _session = Object();
    _accountAttempt = null;
    _sessionFacts?.invalidate();
    emit(state.copyWith(logoutFailure: null));
    disconnectWebSocket();

    final environment = _access?.isTestnet;
    ExchangeFailure? cleanupFailure;
    Future<bool> cleanup() async {
      if (_access != null) {
        await Future.wait(_authenticationsInFlight.toList());
        await Future.wait(_socketOperations.toList());
        disconnectWebSocket();
      }
      final result = environment == null
          ? await _clearExchangeSessionUsecase.execute()
          : await _clearExchangeSessionUsecase.execute(isTestnet: environment);
      if (result case Err(:final failure)) cleanupFailure = failure;
      return result is Ok;
    }

    final access = _access;
    final bool cleared;
    if (access == null) {
      cleared = await cleanup();
    } else {
      final result = await access.disable(cleanup);
      cleared =
          result is Ok<ExchangeAccessOutcome, ExchangeAccessFailure> &&
          result.value == ExchangeAccessOutcome.applied;
    }
    if (isClosed) return null;
    if (!cleared) {
      final failure = cleanupFailure ?? const ExchangeSessionClearFailure();
      // With an access journal, do not reconnect while cleanup is incomplete.
      if (access == null) await connectWebSocket();
      if (!isClosed) emit(state.copyWith(logoutFailure: failure));
      return failure;
    }
    _session = Object();
    _authenticationAttempt = null;
    if (expired && access != null) {
      final generation = access.generation;
      final result = await access.reconcileSession(
        ExchangeSessionFact.expired,
        generation: generation,
      );
      if (result case Err()) return const ExchangeSessionClearFailure();
      if (result case Ok(value: ExchangeAccessOutcome.stale)) return null;
    }
    _sessionFacts?.publish(
      expired ? ExchangeSessionStatus.expired : ExchangeSessionStatus.anonymous,
    );
    if (!isClosed) emit(const ExchangeState());
    return null;
  }

  void clearLogoutFailure() {
    emit(state.copyWith(logoutFailure: null));
  }

  /// Sends the deletion request and logs out only its originating session.
  /// Callers confirm only [ExchangeAccountDeletionOutcome.completed]; stale completions must not update the UI of another session.
  Future<Result<ExchangeAccountDeletionOutcome, ExchangeFailure>>
  deleteAccount() async {
    if (isClosed) return const Ok(ExchangeAccountDeletionOutcome.stale);
    if (!_accountAllowed) return const Err(ExchangeNotAuthenticatedFailure());
    final session = _session;
    final result = await _requestExchangeAccountDeletionUsecase.execute();

    if (isClosed || !identical(_session, session)) {
      return const Ok(ExchangeAccountDeletionOutcome.stale);
    }

    switch (result) {
      case Ok():
        final failure = await logout();
        if (isClosed) return const Ok(ExchangeAccountDeletionOutcome.stale);
        return failure == null
            ? const Ok(ExchangeAccountDeletionOutcome.completed)
            : Err(failure);
      case Err(:final failure):
        return Err(failure);
    }
  }

  Future<void> loadAnnouncements() async {
    if (isClosed || !_accountAllowed) return;
    final session = _session;
    emit(state.copyWith(loadingAnnouncements: true));

    final result = await _getExchangeAnnouncementsUsecase.execute();
    if (isClosed || !identical(_session, session)) return;

    // Decorative: a failure leaves the banner empty and is logged at the
    // boundary rather than shown.
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

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    disconnectWebSocket();
    return super.close();
  }
}
