import 'dart:async';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required SaveExchangeApiKeyUsecase saveExchangeApiKeyUsecase,
    required SaveUserPreferencesUsecase saveUserPreferencesUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _saveExchangeApiKeyUsecase = saveExchangeApiKeyUsecase,
       _saveUserPreferencesUsecase = saveUserPreferencesUsecase,
       super(const ExchangeState());

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final SaveExchangeApiKeyUsecase _saveExchangeApiKeyUsecase;
  final SaveUserPreferencesUsecase _saveUserPreferencesUsecase;

  Future<void> fetchUserSummary() async {
    try {
      // Clear any previous exceptions
      emit(
        state.copyWith(apiKeyException: null, getUserSummaryException: null),
      );

      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(state.copyWith(userSummary: userSummary));
    } catch (e) {
      log.severe('Error during init: $e');
      if (e is ApiKeyException) {
        emit(state.copyWith(apiKeyException: e));
      } else if (e is GetExchangeUserSummaryException) {
        emit(state.copyWith(getUserSummaryException: e));
      }
    }
  }

  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      log.info('Storing API key: $apiKeyData');

      // Clear any previous exceptions
      emit(state.copyWith(saveApiKeyException: null));

      await _saveExchangeApiKeyUsecase.execute(apiKeyResponseData: apiKeyData);
      log.fine('API key successfully stored');

      // Now that the API key is stored, we can try to fetch the user summary
      //  again.
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
    if (state.selectedLanguage == null || state.selectedCurrency == null) {
      return;
    }

    try {
      emit(state.copyWith(isSaving: true));

      await _saveUserPreferencesUsecase.execute(
        language: state.selectedLanguage!,
        currency: state.selectedCurrency,
      );

      emit(state.copyWith(isSaving: false));
    } catch (e) {
      log.severe('Error in savePreferences: $e');
      emit(state.copyWith(isSaving: false));
    }
  }
}
