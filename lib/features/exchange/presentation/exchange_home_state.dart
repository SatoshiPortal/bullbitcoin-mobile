import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_home_state.freezed.dart';

// Exchange State using Freezed
@freezed
abstract class ExchangeHomeState with _$ExchangeHomeState {
  const factory ExchangeHomeState({
    @Default(true) bool isLoading,
    @Default(false) bool hasError,
    @Default('') String errorMessage,
    @Default(false) bool authenticated,
    String? previousUrl,
    @Default('') String currentUrl,
    @Default({}) Map<String, String> allCookies,
    @Default(false) bool apiKeyGenerating,
    String? apiKeyResponse,
    @Default(0) int cookieCheckAttempts,
    @Default(30) int maxCookieCheckAttempts,
    @Default(false) bool showLoginSuccessDialog,
    UserSummary? userSummary,
    @Default(false) bool isFetchingUserSummary,
    Object? error,
    String? bbAuthUrl,
  }) = _ExchangeHomeState;

  const ExchangeHomeState._();

  static List<String> ignoredCookies = [
    'i18n',
    'i18n-lng',
    'i18next',
    'django_language',
    'language',
    'locale',
    'hl',
  ];

  String get loginUrlPattern => 'login';
  String get verificationUrlPattern => 'verification';
  String get registrationUrlPattern => 'registration';
  String get targetAuthCookie => 'bb_session';
  bool get hasUserSummary => userSummary != null;
}
