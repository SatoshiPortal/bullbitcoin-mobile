import 'package:meta/meta.dart';

/// The preferences sent with `saveUserPreferences`, as the server's string
/// values (booleans are `'true'`/`'false'`). Null fields are not sent.
///
/// The server replaces the whole stored set with what is sent.
@immutable
class UserPreferences {
  final String? language;
  final String? defaultFiatCurrencyCode;
  final String? dcaEnabled;
  final String? autoBuyEnabled;
  final String? emailNotifications;

  const UserPreferences({
    this.language,
    this.defaultFiatCurrencyCode,
    this.dcaEnabled,
    this.autoBuyEnabled,
    this.emailNotifications,
  });

  Map<String, String> toJson() => {
    'LANGUAGE': ?language,
    'DEFAULT_FIAT_CURRENCY_CODE': ?defaultFiatCurrencyCode,
    'DCA_ENABLED': ?dcaEnabled,
    'AUTO_BUY_ENABLED': ?autoBuyEnabled,
    'EMAIL_NOTIFICATIONS': ?emailNotifications,
  };
}
