import 'package:bb_mobile/core/utils/constants.dart';
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
    String? previousUrl,
    @Default('') String currentUrl,
    @Default({}) Map<String, String> allCookies,
    @Default(false) bool apiKeyGenerating,
    String? apiKeyResponse,
    @Default(0) int cookieCheckAttempts,
    @Default(30) int maxCookieCheckAttempts,
    @Default(false) bool showLoginSuccessDialog,
  }) = _ExchangeState;

  const ExchangeState._();

  static List<String> ignoredCookies = [
    'i18n',
    'i18n-lng',
    'i18next',
    'django_language',
    'language',
    'locale',
    'hl',
  ];

  String get baseAccountsUrl => 'https://accounts05.bullbitcoin.dev';
  String get loginUrlPattern => 'login';
  String get verificationUrlPattern => 'verification';
  String get registrationUrlPattern => 'registration';

  String get targetAuthCookie => 'bb_session';
  String get baseUrl => ApiServiceConstants.bbAuthUrl;
}
