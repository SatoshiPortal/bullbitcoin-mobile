import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/domain/save_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Exchange Cubit
class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required SaveApiKeyUsecase saveApiKeyUsecase,
  })  : _saveApiKeyUsecase = saveApiKeyUsecase,
        super(
          const ExchangeState(),
        );

  final SaveApiKeyUsecase _saveApiKeyUsecase;

  final String targetAuthCookie = 'bb_session';
  final String baseUrl = ApiServiceConstants.bbAuthUrl;

  void setLoading(bool isLoading) {
    emit(state.copyWith(isLoading: isLoading));
  }

  void setError({bool hasError = true, String message = ''}) {
    emit(
      state.copyWith(
        hasError: hasError,
        errorMessage: message,
        isLoading: false,
      ),
    );
  }

  void setCurrentUrl(String url) {
    emit(state.copyWith(currentUrl: url));
  }

  void incrementCookieCheckAttempts() {
    emit(state.copyWith(cookieCheckAttempts: state.cookieCheckAttempts + 1));
  }

  void resetCookieCheckAttempts() {
    emit(state.copyWith(cookieCheckAttempts: 0));
  }

  void setAuthenticated(bool authenticated) {
    emit(state.copyWith(authenticated: authenticated));
  }

  void updateCookies(Map<String, String> cookies) {
    emit(state.copyWith(allCookies: cookies));
  }

  void setApiKeyGenerating(bool generating) {
    emit(state.copyWith(apiKeyGenerating: generating));
  }

  void setApiKeyResponse(String response) {
    emit(state.copyWith(apiKeyResponse: response));
  }

  // Updated method to store API key
  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      debugPrint('Storing API key: $apiKeyData');

      final jsonString = state.apiKeyResponse;
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('No API key response available to store');
        return;
      }

      final success = await _saveApiKeyUsecase.execute(jsonString);

      if (success) {
        debugPrint('API key successfully stored');
      } else {
        debugPrint('Failed to store API key');
      }
    } catch (e) {
      debugPrint('Error in storeApiKey: $e');
    }
  }
}
