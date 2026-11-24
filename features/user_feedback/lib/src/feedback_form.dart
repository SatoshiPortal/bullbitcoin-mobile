/// The hosted feedback form, set at build time:
/// `--dart-define=FEEDBACK_FORM_URL=https://feedback.example.com/`.
/// Without it the feature stays off: no Settings row, no shake prompt.
const _formUrlFromEnvironment = String.fromEnvironment('FEEDBACK_FORM_URL');

/// Facts about the device and screen sent along with a report.
///
/// Never wallet data: no addresses, balances, amounts or transaction ids.
final class FeedbackContext {
  final String? appVersion;
  final String platform;
  final String? osVersion;
  final String? locale;
  final String? screen;
  final bool dark;

  const FeedbackContext({
    required this.platform,
    required this.dark,
    this.appVersion,
    this.osVersion,
    this.locale,
    this.screen,
  });

  Map<String, String> toQuery() {
    final query = <String, String>{
      'source': 'app',
      'theme': dark ? 'dark' : 'light',
      'platform': platform,
    };
    void put(String key, String? value) {
      if (value != null && value.isNotEmpty) query[key] = value;
    }

    put('app_version', appVersion);
    put('os_version', osVersion);
    put('locale', locale);
    put('screen', screen);
    return query;
  }
}

/// Address of the hosted form, validated once.
final class FeedbackForm {
  final Uri base;

  const FeedbackForm._(this.base);

  /// The form configured for this build, or null when none is.
  static FeedbackForm? fromEnvironment() => parse(_formUrlFromEnvironment);

  /// Accepts an https URL, or http on the local machine for development.
  static FeedbackForm? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme == 'https' || (uri.scheme == 'http' && local)) {
      return FeedbackForm._(uri);
    }
    return null;
  }

  /// The form address carrying [context] as query parameters.
  Uri uriFor(FeedbackContext context) => base.replace(
    queryParameters: {...base.queryParameters, ...context.toQuery()},
  );

  /// Whether [other] stays on the form's site; anything else is blocked.
  bool owns(Uri other) => other.origin == base.origin;
}
