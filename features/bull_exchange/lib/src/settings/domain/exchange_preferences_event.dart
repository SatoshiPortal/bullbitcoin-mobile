import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/exchange_preferences.dart';

@immutable
sealed class PreferencesEvent {
  const PreferencesEvent();
}

final class PreferencesLoaded extends PreferencesEvent {
  final int attempt;
  final Result<ExchangePreferences, ExchangeFailure> result;

  const PreferencesLoaded(this.attempt, this.result);
}

final class PreferencesRetryPressed extends PreferencesEvent {
  const PreferencesRetryPressed();
}

final class PreferencesLanguageChosen extends PreferencesEvent {
  final String language;

  const PreferencesLanguageChosen(this.language);
}

final class PreferencesCurrencyChosen extends PreferencesEvent {
  final String currency;

  const PreferencesCurrencyChosen(this.currency);
}

final class PreferencesEmailToggled extends PreferencesEvent {
  final bool enabled;

  const PreferencesEmailToggled(this.enabled);
}

final class PreferencesSavePressed extends PreferencesEvent {
  const PreferencesSavePressed();
}

/// The answer of the one write in flight (Saving is left only by it, so it
/// needs no tag).
final class PreferencesSaveAnswered extends PreferencesEvent {
  final Result<void, ExchangeFailure> answer;

  const PreferencesSaveAnswered(this.answer);
}
