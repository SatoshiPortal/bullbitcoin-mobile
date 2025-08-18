import 'dart:async';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
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
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _saveExchangeApiKeyUsecase = saveExchangeApiKeyUsecase,
       _saveUserPreferencesUsecase = saveUserPreferencesUsecase,
       _deleteExchangeApiKeyUsecase = deleteExchangeApiKeyUsecase,
       super(const ExchangeState());

  Timer? _pollingTimer;

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final SaveExchangeApiKeyUsecase _saveExchangeApiKeyUsecase;
  final SaveUserPreferencesUsecase _saveUserPreferencesUsecase;
  final DeleteExchangeApiKeyUsecase _deleteExchangeApiKeyUsecase;

  Future<void> fetchUserSummary() async {
    try {
      log.info('Fetching user summary');

      emit(
        state.copyWith(apiKeyException: null, getUserSummaryException: null),
      );

      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(state.copyWith(userSummary: userSummary));
      emit(state.copyWith(selectedLanguage: userSummary.language));
      emit(state.copyWith(selectedCurrency: userSummary.currency));

      startPolling();
    } catch (e) {
      log.severe('Error during init: $e');
      if (e is ApiKeyException) {
        emit(state.copyWith(apiKeyException: e));
        // Stop polling if API key is invalid
        stopPolling();
      } else if (e is GetExchangeUserSummaryException) {
        emit(state.copyWith(getUserSummaryException: e));
      }
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!state.notLoggedIn) {
        fetchUserSummary();
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      emit(state.copyWith(saveApiKeyException: null));

      await _saveExchangeApiKeyUsecase.execute(apiKeyResponseData: apiKeyData);
      log.fine('API key successfully stored');

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

  Future<void> savePreferences() async {
    if (state.selectedLanguage == null && state.selectedCurrency == null) {
      return;
    }

    try {
      emit(state.copyWith(isSaving: true));

      await _saveUserPreferencesUsecase.execute(
        language: state.selectedLanguage,
        currency: state.selectedCurrency,
      );

      emit(state.copyWith(isSaving: false));
    } catch (e) {
      log.severe('Error in savePreferences: $e');
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> logout() async {
    try {
      log.info('Logging out from exchange');

      stopPolling();

      emit(state.copyWith(deleteApiKeyException: null));
      await _deleteExchangeApiKeyUsecase.execute();

      final cookieManager = WebviewCookieManager();
      await cookieManager.clearCookies();

      emit(
        state.copyWith(
          userSummary: null,
          selectedLanguage: null,
          selectedCurrency: null,
        ),
      );

      log.info('Successfully logged out from exchange');
    } catch (e) {
      log.severe('Error in logout: $e');
      if (e is DeleteExchangeApiKeyException) {
        emit(state.copyWith(deleteApiKeyException: e));
      }
    }
  }

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
