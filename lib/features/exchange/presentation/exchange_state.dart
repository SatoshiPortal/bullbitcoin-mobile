import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_state.freezed.dart';

// Exchange State using Freezed
@freezed
class ExchangeState with _$ExchangeState {
  const factory ExchangeState({
    @Default(true) bool isLoading,
    @Default(false) bool hasError,
    @Default('') String errorMessage,
    @Default(false) bool authenticated,
    @Default('') String currentUrl,
    @Default({}) Map<String, String> allCookies,
    @Default(false) bool apiKeyGenerating,
    String? apiKeyResponse,
    @Default(0) int cookieCheckAttempts,
    @Default(30) int maxCookieCheckAttempts,
    @Default(false) bool showLoginSuccessDialog,
  }) = _ExchangeState;

  const ExchangeState._();
}
