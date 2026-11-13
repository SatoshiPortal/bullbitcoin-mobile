import 'dart:async';
import '../domain/exchange_access.dart';
import '../domain/exchange_failure.dart';
import '../domain/usecases/get_exchange_account_usecase.dart';
import '../domain/usecases/get_exchange_announcements_usecase.dart';
import '../domain/usecases/save_exchange_preferences_usecase.dart';
import '../domain/usecases/delete_exchange_account_usecase.dart';
import '../domain/usecases/watch_exchange_access_usecase.dart';
import '../domain/usecases/watch_exchange_notifications_usecase.dart';
import 'exchange_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

export '../domain/usecases/delete_exchange_account_usecase.dart'
    show ExchangeAccountDeletionOutcome;

/// Presentation of account data only. Access and credential mutations are use cases.
class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required GetExchangeAccountUsecase getExchangeAccountUsecase,
    required SaveExchangePreferencesUsecase saveExchangePreferencesUsecase,
    required GetExchangeAnnouncementsUsecase getExchangeAnnouncementsUsecase,
    required this._deleteAccount,
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
        unawaited(fetchUserSummary());
      } else {
        emit(const ExchangeState());
      }
    });
  }
  final WatchExchangeAccessUsecase _watchAccess;
  final GetExchangeAccountUsecase _getAccount;
  final SaveExchangePreferencesUsecase _savePreferences;
  final GetExchangeAnnouncementsUsecase _getAnnouncements;
  final DeleteExchangeAccountUsecase _deleteAccount;
  final WatchExchangeNotificationsUsecase _watchNotifications;
  StreamSubscription<Object?>? _notifications;
  StreamSubscription<ExchangeAccess>? _access;

  Future<void> fetchUserSummary() async {
    if (isClosed) return;
    final result = await _getAccount.execute();
    if (isClosed ||
        _watchAccess.current is! ExchangeAccessEnabled ||
        (_watchAccess.current as ExchangeAccessEnabled).session !=
            ExchangeAccessSession.signedIn) {
      return;
    }
    switch (result) {
      case Err(failure: ExchangeOperationStaleFailure()):
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
