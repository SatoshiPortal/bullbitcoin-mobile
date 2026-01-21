import 'dart:async';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_announcements_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required SaveExchangeApiKeyUsecase saveExchangeApiKeyUsecase,
    required SaveUserPreferencesUsecase saveUserPreferencesUsecase,
    required DeleteExchangeApiKeyUsecase deleteExchangeApiKeyUsecase,
    required GetAnnouncementsUsecase getAnnouncementsUsecase,
    required ExchangeNotificationService exchangeNotificationService,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _saveExchangeApiKeyUsecase = saveExchangeApiKeyUsecase,
       _saveUserPreferencesUsecase = saveUserPreferencesUsecase,
       _deleteExchangeApiKeyUsecase = deleteExchangeApiKeyUsecase,
       _getAnnouncementsUsecase = getAnnouncementsUsecase,
       _exchangeNotificationService = exchangeNotificationService,
       super(const ExchangeState()) {
    _notificationSubscription = _exchangeNotificationService.messageStream
        .where(
          (message) =>
              message.type == 'balance' ||
              message.type == 'group' ||
              message.type == 'kyc',
        )
        .listen((_) => fetchUserSummary());
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final SaveExchangeApiKeyUsecase _saveExchangeApiKeyUsecase;
  final SaveUserPreferencesUsecase _saveUserPreferencesUsecase;
  final DeleteExchangeApiKeyUsecase _deleteExchangeApiKeyUsecase;
  final GetAnnouncementsUsecase _getAnnouncementsUsecase;
  final ExchangeNotificationService _exchangeNotificationService;
  StreamSubscription<NotificationMessage>? _notificationSubscription;

  Future<void> connectWebSocket() async {
    try {
      await _exchangeNotificationService.connect();
    } catch (e) {
      log.warning('WebSocket connection failed: $e');
    }
  }

  void disconnectWebSocket() {
    _exchangeNotificationService.disconnect();
  }

  /// Call this when the network environment changes to reconnect to the correct WebSocket
  Future<void> reconnectWebSocket() async {
    try {
      await _exchangeNotificationService.reconnect();
    } catch (e) {
      log.warning('WebSocket reconnection failed: $e');
    }
  }

  Future<void> fetchUserSummary({bool force = false}) async {
    try {
      emit(
        state.copyWith(apiKeyException: null, getUserSummaryException: null),
      );

      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(state.copyWith(userSummary: userSummary));

      if (force) {
        emit(
          state.copyWith(
            selectedLanguage: userSummary.language,
            selectedCurrency: userSummary.currency,
            selectedEmailNotifications: userSummary.emailNotificationsEnabled,
          ),
        );
      }

      loadAnnouncements();
    } catch (e) {
      log.severe('$ExchangeCubit init: $e');
      if (e is ApiKeyException) {
        emit(state.copyWith(apiKeyException: e));
        // Disconnect WebSocket if API key is invalid
        disconnectWebSocket();
      } else if (e is GetExchangeUserSummaryException) {
        emit(state.copyWith(getUserSummaryException: e));
      }
    }
  }

  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      emit(state.copyWith(saveApiKeyException: null));

      await _saveExchangeApiKeyUsecase.execute(apiKeyResponseData: apiKeyData);

      await fetchUserSummary();
    } catch (e) {
      log.severe('Error in storeApiKey: $e');
      if (e is SaveExchangeApiKeyException) {
        emit(state.copyWith(saveApiKeyException: e));
      }
    }
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

    try {
      emit(state.copyWith(isSaving: true));

      await _saveUserPreferencesUsecase.execute(
        language: state.selectedLanguage,
        currency: state.selectedCurrency,
        emailNotificationsEnabled: state.selectedEmailNotifications,
        dcaEnabled: state.userSummary?.dca.isActive,
        autoBuyEnabled: state.userSummary?.autoBuy.isActive.toString(),
      );

      emit(state.copyWith(isSaving: false));

      await fetchUserSummary(force: true);
    } catch (e) {
      log.severe('Error in savePreferences: $e');
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> stopDca() async {
    try {
      emit(state.copyWith(isSaving: true));

      await _saveUserPreferencesUsecase.execute(dcaEnabled: false);

      // Trigger a refresh of the user summary to be sure the Dca was stopped
      await fetchUserSummary();
    } catch (e) {
      log.severe('Error in stopDca: $e');
    } finally {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> logout() async {
    try {
      disconnectWebSocket();

      emit(state.copyWith(deleteApiKeyException: null));
      await _deleteExchangeApiKeyUsecase.execute();

      final cookieManager = WebviewCookieManager();
      await cookieManager.clearCookies();

      emit(
        state.copyWith(
          userSummary: null,
          selectedLanguage: null,
          selectedCurrency: null,
          selectedEmailNotifications: null,
        ),
      );
    } catch (e) {
      log.severe('Error in logout: $e');
      if (e is DeleteExchangeApiKeyException) {
        emit(state.copyWith(deleteApiKeyException: e));
      }
    }
  }

  void loadAnnouncements() async {
    emit(
      state.copyWith(loadingAnnouncements: true, errLoadingAnnouncements: null),
    );
    try {
      final announcements = await _getAnnouncementsUsecase.execute();
      emit(
        state.copyWith(
          announcements: announcements,
          loadingAnnouncements: false,
        ),
      );
    } catch (e) {
      log.warning('Failed to load announcements: $e');
      emit(
        state.copyWith(
          errLoadingAnnouncements: e.toString(),
          loadingAnnouncements: false,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    disconnectWebSocket();
    return super.close();
  }
}
