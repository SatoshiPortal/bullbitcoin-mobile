import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Exchange Cubit
class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit() : super(const ExchangeState());

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

  // Method to store API key - skeleton implementation
  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    // TODO: Implement API key storage logic
    // This would potentially store the API key in secure storage
    // or pass it to another part of the application
    debugPrint('Storing API key: $apiKeyData');
  }
}
