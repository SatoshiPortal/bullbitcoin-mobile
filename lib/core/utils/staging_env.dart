import 'package:flutter/foundation.dart';

class StagingEnv {
  StagingEnv._();

  static const _apiUrl = String.fromEnvironment('STAGING_API_URL');
  static const _authUrl = String.fromEnvironment('STAGING_AUTH_URL');
  static const _kycUrl = String.fromEnvironment('STAGING_KYC_URL');
  static const _username = String.fromEnvironment('STAGING_BASIC_AUTH_USERNAME');
  static const _password = String.fromEnvironment('STAGING_BASIC_AUTH_PASSWORD');

  static bool get isConfigured {
    if (kReleaseMode) return false;
    return _apiUrl.trim().isNotEmpty &&
        _authUrl.trim().isNotEmpty &&
        _kycUrl.trim().isNotEmpty &&
        _username.trim().isNotEmpty &&
        _password.trim().isNotEmpty;
  }

  static String? get apiUrl => isConfigured ? _apiUrl.trim() : null;

  static String? get authUrl => isConfigured ? _authUrl.trim() : null;

  static String? get kycUrl => isConfigured ? _kycUrl.trim() : null;

  static String? get basicAuthUsername => isConfigured ? _username.trim() : null;

  static String? get basicAuthPassword => isConfigured ? _password.trim() : null;
}
