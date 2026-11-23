final class ExchangePreferences {
  final String? language;
  final String? currency;
  final bool emailNotificationsEnabled;

  const ExchangePreferences({
    required this.language,
    required this.currency,
    required this.emailNotificationsEnabled,
  });

  bool get isComplete => language != null && currency != null;

  ExchangePreferences copyWith({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
  }) => ExchangePreferences(
    language: language ?? this.language,
    currency: currency ?? this.currency,
    emailNotificationsEnabled:
        emailNotificationsEnabled ?? this.emailNotificationsEnabled,
  );
}
