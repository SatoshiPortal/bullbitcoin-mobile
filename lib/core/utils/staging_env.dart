import 'package:flutter/foundation.dart';

class StagingEnv {
  StagingEnv._();

  static const _apiUrl = String.fromEnvironment('STAGING_API_URL');
  static const _authUrl = String.fromEnvironment('STAGING_AUTH_URL');
  static const _kycUrl = String.fromEnvironment('STAGING_KYC_URL');
  static const _username = String.fromEnvironment(
    'STAGING_BASIC_AUTH_USERNAME',
  );
  static const _password = String.fromEnvironment(
    'STAGING_BASIC_AUTH_PASSWORD',
  );

  static bool get isConfigured {
    if (kReleaseMode) return false;
    return _apiUrl.trim().isNotEmpty &&
        _authUrl.trim().isNotEmpty &&
        _kycUrl.trim().isNotEmpty &&
        _username.trim().isNotEmpty &&
        _password.trim().isNotEmpty;
  }

  static bool useTestnetExchange(bool isTestnet) => isTestnet && isConfigured;

  static String get apiUrl => _apiUrl.trim();

  static String get authUrl => _authUrl.trim();

  static String get kycUrl => _kycUrl.trim();

  static String get basicAuthUsername => _username.trim();

  static String get basicAuthPassword => _password.trim();
}
