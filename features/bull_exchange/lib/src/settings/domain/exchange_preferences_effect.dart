import 'package:meta/meta.dart';

import 'entities/exchange_preferences.dart';

@immutable
sealed class PreferencesEffect {
  const PreferencesEffect();
}

final class FetchPreferences extends PreferencesEffect {
  final int attempt;

  const FetchPreferences(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FetchPreferences && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FetchPreferences, attempt);
}

final class SavePreferences extends PreferencesEffect {
  final ExchangePreferences saved;
  final ExchangePreferences edited;

  const SavePreferences(this.saved, this.edited);

  @override
  bool operator ==(Object other) =>
      other is SavePreferences &&
      other.saved == saved &&
      other.edited == edited;

  @override
  int get hashCode => Object.hash(SavePreferences, saved, edited);
}
