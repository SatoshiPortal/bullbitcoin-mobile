import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart' show StepNext;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/exchange_preferences.dart';
import '../domain/exchange_settings_failure.dart';

/// [saved] is what the account has; [draft] what the screen shows.
@immutable
sealed class PreferencesState {
  const PreferencesState();
}

final class PreferencesLoading extends PreferencesState {
  final int attempt;

  const PreferencesLoading(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is PreferencesLoading && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(PreferencesLoading, attempt);
}

final class PreferencesLoadFailed extends PreferencesState {
  final int attempt;
  final ExchangeSettingsFailure failure;

  const PreferencesLoadFailed(this.attempt, this.failure);

  @override
  bool operator ==(Object other) =>
      other is PreferencesLoadFailed &&
      other.attempt == attempt &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(PreferencesLoadFailed, attempt, failure);
}

/// The session ended: a Retry can't help, the user has to sign in (SET-3).
final class PreferencesSignedOut extends PreferencesState {
  const PreferencesSignedOut();

  @override
  bool operator ==(Object other) => other is PreferencesSignedOut;

  @override
  int get hashCode => (PreferencesSignedOut).hashCode;
}

final class PreferencesEditing extends PreferencesState {
  final ExchangePreferences saved;
  final ExchangePreferences draft;

  const PreferencesEditing(this.saved, this.draft);

  @override
  bool operator ==(Object other) =>
      other is PreferencesEditing &&
      other.saved == saved &&
      other.draft == draft;

  @override
  int get hashCode => Object.hash(PreferencesEditing, saved, draft);
}

/// [inFlight] is being written; edits made meanwhile go to [draft] (SET-2).
final class PreferencesSaving extends PreferencesState {
  final ExchangePreferences saved;
  final ExchangePreferences inFlight;
  final ExchangePreferences draft;

  const PreferencesSaving(this.saved, this.inFlight, this.draft);

  @override
  bool operator ==(Object other) =>
      other is PreferencesSaving &&
      other.saved == saved &&
      other.inFlight == inFlight &&
      other.draft == draft;

  @override
  int get hashCode => Object.hash(PreferencesSaving, saved, inFlight, draft);
}

/// The write succeeded and the screen shows exactly what was written.
final class PreferencesSaved extends PreferencesState {
  final ExchangePreferences saved;

  const PreferencesSaved(this.saved);

  @override
  bool operator ==(Object other) =>
      other is PreferencesSaved && other.saved == saved;

  @override
  int get hashCode => Object.hash(PreferencesSaved, saved);
}

/// The write failed: [saved] is still what the account has, [draft] is
/// kept for another try.
final class PreferencesSaveFailed extends PreferencesState {
  final ExchangePreferences saved;
  final ExchangePreferences draft;
  final ExchangeSettingsFailure failure;

  const PreferencesSaveFailed(this.saved, this.draft, this.failure);

  @override
  bool operator ==(Object other) =>
      other is PreferencesSaveFailed &&
      other.saved == saved &&
      other.draft == draft &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(PreferencesSaveFailed, saved, draft, failure);
}

@immutable
sealed class PreferencesEvent {
  const PreferencesEvent();
}

final class PreferencesLoaded extends PreferencesEvent {
  final int attempt;
  final Result<ExchangePreferences, ExchangeSettingsFailure> result;

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
  final GatedWrite<Result<void, ExchangeSettingsFailure>> answer;

  const PreferencesSaveAnswered(this.answer);
}

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

typedef PreferencesNext = StepNext<PreferencesState, PreferencesEffect>;

PreferencesNext preferencesStart({required bool signedIn}) => signedIn
    ? StepNext(const PreferencesLoading(1), const [FetchPreferences(1)])
    : StepNext(const PreferencesSignedOut());

ExchangePreferences _edit(ExchangePreferences draft, PreferencesEvent edit) =>
    switch (edit) {
      PreferencesLanguageChosen(:final language) => draft.copyWith(
        language: language,
      ),
      PreferencesCurrencyChosen(:final currency) => draft.copyWith(
        currency: currency,
      ),
      PreferencesEmailToggled(:final enabled) => draft.copyWith(
        emailNotificationsEnabled: enabled,
      ),
      PreferencesLoaded() ||
      PreferencesRetryPressed() ||
      PreferencesSavePressed() ||
      PreferencesSaveAnswered() => draft,
    };

PreferencesNext _save(ExchangePreferences saved, ExchangePreferences draft) =>
    StepNext(PreferencesSaving(saved, draft, draft), [
      SavePreferences(saved, draft),
    ]);

PreferencesNext transitionPreferences(
  PreferencesState state,
  PreferencesEvent event,
) => switch ((state, event)) {
  (PreferencesLoading(:final attempt), PreferencesLoaded loaded)
      when loaded.attempt == attempt =>
    StepNext(switch (loaded.result) {
      Ok(:final value) => PreferencesEditing(value, value),
      Err(failure: ExchangeSettingsNotAuthenticatedFailure()) =>
        const PreferencesSignedOut(),
      Err(:final failure) => PreferencesLoadFailed(attempt, failure),
    }),
  (
    PreferencesLoading() ||
        PreferencesLoadFailed() ||
        PreferencesSignedOut() ||
        PreferencesEditing() ||
        PreferencesSaving() ||
        PreferencesSaved() ||
        PreferencesSaveFailed(),
    PreferencesLoaded(),
  ) =>
    StepNext.stay(state),
  (PreferencesLoadFailed(:final attempt), PreferencesRetryPressed()) =>
    StepNext(PreferencesLoading(attempt + 1), [FetchPreferences(attempt + 1)]),
  (
    PreferencesLoading() ||
        PreferencesSignedOut() ||
        PreferencesEditing() ||
        PreferencesSaving() ||
        PreferencesSaved() ||
        PreferencesSaveFailed(),
    PreferencesRetryPressed(),
  ) =>
    StepNext.stay(state),
  (
    PreferencesEditing(:final saved, :final draft) ||
        PreferencesSaveFailed(:final saved, :final draft),
    PreferencesLanguageChosen() ||
        PreferencesCurrencyChosen() ||
        PreferencesEmailToggled(),
  ) =>
    StepNext(PreferencesEditing(saved, _edit(draft, event))),
  (
    PreferencesSaved(:final saved),
    PreferencesLanguageChosen() ||
        PreferencesCurrencyChosen() ||
        PreferencesEmailToggled(),
  ) =>
    StepNext(PreferencesEditing(saved, _edit(saved, event))),
  (
    PreferencesSaving(:final saved, :final inFlight, :final draft),
    PreferencesLanguageChosen() ||
        PreferencesCurrencyChosen() ||
        PreferencesEmailToggled(),
  ) =>
    StepNext(PreferencesSaving(saved, inFlight, _edit(draft, event))),
  (
    PreferencesLoading() || PreferencesLoadFailed() || PreferencesSignedOut(),
    PreferencesLanguageChosen() ||
        PreferencesCurrencyChosen() ||
        PreferencesEmailToggled(),
  ) =>
    StepNext.stay(state),
  (
    PreferencesEditing(:final saved, :final draft) ||
        PreferencesSaveFailed(:final saved, :final draft),
    PreferencesSavePressed(),
  )
      when draft.isComplete && draft != saved =>
    _save(saved, draft),
  (
    PreferencesLoading() ||
        PreferencesLoadFailed() ||
        PreferencesSignedOut() ||
        PreferencesEditing() ||
        PreferencesSaving() ||
        PreferencesSaved() ||
        PreferencesSaveFailed(),
    PreferencesSavePressed(),
  ) =>
    StepNext.stay(state),
  (
    PreferencesSaving(:final saved, :final inFlight, :final draft),
    PreferencesSaveAnswered(:final answer),
  ) =>
    StepNext(switch (answer) {
      GateAdmitted(result: Ok()) =>
        draft == inFlight
            ? PreferencesSaved(inFlight)
            : PreferencesEditing(inFlight, draft),
      GateAdmitted(
        result: Err(failure: ExchangeSettingsNotAuthenticatedFailure()),
      ) =>
        const PreferencesSignedOut(),
      GateAdmitted(result: Err(:final failure)) => PreferencesSaveFailed(
        saved,
        draft,
        failure,
      ),
      GateRefused() => PreferencesSaveFailed(
        saved,
        draft,
        const ExchangeSettingsWriteBusyFailure(),
      ),
    }),
  (
    PreferencesLoading() ||
        PreferencesLoadFailed() ||
        PreferencesSignedOut() ||
        PreferencesEditing() ||
        PreferencesSaved() ||
        PreferencesSaveFailed(),
    PreferencesSaveAnswered(),
  ) =>
    StepNext.stay(state),
};

/// What the screen shows, for every state that has preferences.
ExchangePreferences? shownPreferences(PreferencesState state) =>
    switch (state) {
      PreferencesEditing(:final draft) ||
      PreferencesSaving(:final draft) ||
      PreferencesSaveFailed(:final draft) => draft,
      PreferencesSaved(:final saved) => saved,
      PreferencesLoading() ||
      PreferencesLoadFailed() ||
      PreferencesSignedOut() => null,
    };
