import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/clear_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/store_exchange_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class ExchangeCubit extends Cubit<ExchangeState> {
  final GetExchangeAccountUsecase _getExchangeAccountUsecase;
  final StoreExchangeApiKeyUsecase _storeExchangeApiKeyUsecase;
  final SaveExchangePreferencesUsecase _saveExchangePreferencesUsecase;
  final ClearExchangeSessionUsecase _clearExchangeSessionUsecase;
  final GetExchangeAnnouncementsUsecase _getExchangeAnnouncementsUsecase;
  final RequestExchangeAccountDeletionUsecase
  _requestExchangeAccountDeletionUsecase;
  final WatchExchangeNotificationsUsecase _watchExchangeNotificationsUsecase;

  StreamSubscription<NotificationMessage>? _notificationSubscription;

  ExchangeCubit({
    required this._getExchangeAccountUsecase,
    required this._storeExchangeApiKeyUsecase,
    required this._saveExchangePreferencesUsecase,
    required this._clearExchangeSessionUsecase,
    required this._getExchangeAnnouncementsUsecase,
    required this._requestExchangeAccountDeletionUsecase,
    required this._watchExchangeNotificationsUsecase,
  }) : super(const ExchangeState()) {
    _notificationSubscription = _watchExchangeNotificationsUsecase
        .accountChanges()
        .listen((_) => fetchUserSummary());
  }

  /// Best-effort: the socket failure is logged at the repository boundary and
  /// deliberately not surfaced — the exchange works without notifications.
  Future<void> connectWebSocket() async {
    // Result deliberately discarded: logged at the repository boundary.
    final _ = await _watchExchangeNotificationsUsecase.connect();
  }

  void disconnectWebSocket() => _watchExchangeNotificationsUsecase.disconnect();

  /// Call this when the network environment changes to reconnect to the
  /// correct WebSocket.
  Future<void> reconnectWebSocket() async {
    final _ = await _watchExchangeNotificationsUsecase.reconnect();
  }

  Future<void> fetchUserSummary({bool force = false}) async {
    emit(state.copyWith(getUserSummaryFailure: null));

    final result = await _getExchangeAccountUsecase.execute();
    if (isClosed) return;

    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(getUserSummaryFailure: failure));
        return;
      case Ok(:final value):
        emit(
          force
              ? state.copyWith(
                  userSummary: value,
                  selectedLanguage: value.language,
                  selectedCurrency: value.currency,
                  selectedEmailNotifications: value.emailNotificationsEnabled,
                )
              : state.copyWith(userSummary: value),
        );
    }

    await loadAnnouncements();
  }

  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    emit(state.copyWith(saveApiKeyFailure: null));

    final result = await _storeExchangeApiKeyUsecase.execute(apiKeyData);
    if (isClosed) return;

    if (result case Err(:final failure)) {
      emit(state.copyWith(saveApiKeyFailure: failure));
      return;
    }

    await fetchUserSummary();
  }

  void updateSelectedLanguage(String? language) {
    emit(state.copyWith(selectedLanguage: language));
  }

  void updateSelectedCurrency(String? currency) {
    emit(state.copyWith(selectedCurrency: currency));
  }

  void updateSelectedEmailNotifications(bool enabled) {
    emit(state.copyWith(selectedEmailNotifications: enabled));
  }

  Future<void> savePreferences() async {
    if (state.selectedLanguage == null && state.selectedCurrency == null) {
      return;
    }

    emit(state.copyWith(isSaving: true, savePreferencesFailure: null));

    final result = await _saveExchangePreferencesUsecase.execute(
      language: state.selectedLanguage,
      currency: state.selectedCurrency,
      emailNotificationsEnabled: state.selectedEmailNotifications,
      dcaEnabled: state.userSummary?.dca.isActive,
      autoBuyEnabled: state.userSummary?.autoBuy.isActive.toString(),
    );
    if (isClosed) return;

    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, savePreferencesFailure: failure));
        return;
      case Ok():
        emit(state.copyWith(isSaving: false));
    }

    await fetchUserSummary(force: true);
  }

  void clearSavePreferencesFailure() {
    emit(state.copyWith(savePreferencesFailure: null));
  }

  void clearStopDcaFailure() {
    emit(state.copyWith(stopDcaFailure: null));
  }

  Future<void> stopDca() async {
    emit(state.copyWith(isSaving: true, stopDcaFailure: null));

    final result = await _saveExchangePreferencesUsecase.execute(
      dcaEnabled: false,
    );
    if (isClosed) return;

    if (result case Err(:final failure)) {
      // Surfaced, not swallowed: otherwise the tile silently keeps saying the
      // recurring buy is active and the user has no idea the stop failed.
      emit(state.copyWith(isSaving: false, stopDcaFailure: failure));
      return;
    }

    // Refresh so the tile reflects whatever the server actually holds rather
    // than what we hoped it would hold.
    await fetchUserSummary();
    if (isClosed) return;

    emit(state.copyWith(isSaving: false));
  }

  /// Returns the failure when the session could not be cleared.
  ///
  /// Local state is NOT cleared in that case, and that is deliberate: if the
  /// stored API key survives, showing a signed-out UI would be a lie — the
  /// next `fetchUserSummary` (app restart, notification refresh) would sign
  /// the user straight back in. On a shared device that is the difference
  /// between believing the session is gone and it still being live.
  Future<ExchangeFailure?> logout() async {
    emit(state.copyWith(logoutFailure: null));
    disconnectWebSocket();

    final cleared = await _clearExchangeSessionUsecase.execute();
    if (isClosed) return null;

    if (cleared case Err(:final failure)) {
      // Reconnect: the session is still live, so the socket should be too.
      await connectWebSocket();
      if (isClosed) return null;
      emit(state.copyWith(logoutFailure: failure));
      return failure;
    }

    emit(
      state.copyWith(
        userSummary: null,
        selectedLanguage: null,
        selectedCurrency: null,
        selectedEmailNotifications: null,
        // Every failure belonged to the session that just ended. Leaving one
        // behind would re-show its banner to whoever signs in next.
        getUserSummaryFailure: null,
        saveApiKeyFailure: null,
        savePreferencesFailure: null,
        stopDcaFailure: null,
        logoutFailure: null,
      ),
    );
    return null;
  }

  void clearLogoutFailure() {
    emit(state.copyWith(logoutFailure: null));
  }

  /// Sends the account-deletion request to support and logs out. Returns the
  /// failure when the request could not be sent — callers must NOT show a
  /// success confirmation in that case. The raw reason is logged at the
  /// boundary.
  Future<ExchangeFailure?> deleteAccount() async {
    final result = await _requestExchangeAccountDeletionUsecase.execute();

    switch (result) {
      case Ok():
        // The request reached support, but if the session survives the user
        // is still signed in — report that rather than confirming success.
        return logout();
      case Err(:final failure):
        return failure;
    }
  }

  Future<void> loadAnnouncements() async {
    emit(state.copyWith(loadingAnnouncements: true));

    final result = await _getExchangeAnnouncementsUsecase.execute();
    if (isClosed) return;

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
