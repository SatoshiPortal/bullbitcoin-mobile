import 'dart:async';

import 'package:exchange/exchange.dart';

import 'exchange_state.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Presents account data and forwards access operations to their use cases.
class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required this._getAccount,
    required this._getAnnouncements,
    required this._stopDca,
    required this._currentAccess,
    required Stream<ExchangeAccess> accessChanges,
    required Stream<NotificationMessage> accountChanges,
    required Stream<NotificationMessage> supportMessages,
    required this._getUnreadSupportMessageCount,
    required this._markSupportMessagesRead,
    required this._connectNotifications,
    required this._disconnectNotifications,
  }) : super(const ExchangeState()) {
    _notifications = accountChanges.listen((_) => fetchUserSummary());
    _supportMessages = supportMessages.listen(
      (_) => refreshUnreadSupportMessages(),
    );
    _access = accessChanges.listen((access) {
      if (isClosed) return;
      if (access case ExchangeAccessEnabled(
        session: ExchangeAccessSession.signedIn,
      )) {
        // Reconciliation disconnects before it emits signed in, and an
        // unchanged account emits no summary transition to reopen the socket.
        unawaited(fetchUserSummary());
        unawaited(connectWebSocket());
        unawaited(refreshUnreadSupportMessages());
      } else {
        _accountAttempt++;
        _unreadAttempt++;
        emit(const ExchangeState());
      }
    });
  }
  final Future<Result<UserSummary, ExchangeFailure>> Function() _getAccount;
  final Future<Result<List<Announcement>, ExchangeFailure>> Function()
  _getAnnouncements;
  final Future<Result<void, ExchangeFailure>> Function() _stopDca;
  final ExchangeAccess Function() _currentAccess;
  final Future<Result<void, ExchangeFailure>> Function({
    required bool reconnect,
  })
  _connectNotifications;
  final void Function() _disconnectNotifications;
  final Future<Result<int, ExchangeFailure>> Function()
  _getUnreadSupportMessageCount;
  final Future<Result<void, ExchangeFailure>> Function()
  _markSupportMessagesRead;
  StreamSubscription<Object?>? _notifications;
  StreamSubscription<Object?>? _supportMessages;
  int _unreadAttempt = 0;
  StreamSubscription<ExchangeAccess>? _access;
  int _accountAttempt = 0;

  Future<void> fetchUserSummary() async {
    if (isClosed) return;
    final attempt = ++_accountAttempt;
    if (state.getUserSummaryFailure != null) {
      emit(state.copyWith(getUserSummaryFailure: null));
    }
    final result = await _getAccount();
    final current = _currentAccess();
    if (isClosed ||
        attempt != _accountAttempt ||
        current is! ExchangeAccessEnabled ||
        current.session != ExchangeAccessSession.signedIn) {
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
    final result = await _stopDca();
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
    Future<Result<void, ExchangeFailure>> Function({
      required bool Function() isCurrent,
    })
    authenticate, {
    required bool Function() isCurrent,
  }) async {
    final result = await authenticate(
      isCurrent: () => !isClosed && isCurrent(),
    );
    if (result is Ok && !isClosed && isCurrent()) await fetchUserSummary();
    return result;
  }

  Future<void> loadAnnouncements() async {
    if (isClosed || !state.hasUser) return;
    final result = await _getAnnouncements();
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

  /// The badge keeps its last known count when the read fails.
  Future<void> refreshUnreadSupportMessages() async {
    if (isClosed) return;
    final attempt = ++_unreadAttempt;
    final result = await _getUnreadSupportMessageCount();
    if (isClosed || attempt != _unreadAttempt) return;
    if (result case Ok(:final value)) {
      emit(state.copyWith(unreadSupportMessages: value));
    }
  }

  /// Clears the badge at once, then confirms the count with the server.
  Future<void> markSupportMessagesRead() async {
    if (isClosed) return;
    _unreadAttempt++;
    if (state.unreadSupportMessages != 0) {
      emit(state.copyWith(unreadSupportMessages: 0));
    }
    final _ = await _markSupportMessagesRead();
    await refreshUnreadSupportMessages();
  }

  Future<void> connectWebSocket() async {
    final _ = await _connectNotifications(reconnect: false);
  }

  Future<void> reconnectWebSocket() async {
    final _ = await _connectNotifications(reconnect: true);
  }

  void disconnectWebSocket() => _disconnectNotifications();
  @override
  Future<void> close() async {
    await _notifications?.cancel();
    await _supportMessages?.cancel();
    await _access?.cancel();
    _disconnectNotifications();
    return super.close();
  }
}
