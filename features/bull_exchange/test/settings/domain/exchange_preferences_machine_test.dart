import 'package:bull_exchange/src/settings/domain/entities/exchange_preferences.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/domain/exchange_preferences_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _a = ExchangePreferences(
  language: 'EN',
  currency: 'CAD',
  emailNotificationsEnabled: true,
);
const _b = ExchangePreferences(
  language: 'FR',
  currency: 'CAD',
  emailNotificationsEnabled: true,
);
const _c = ExchangePreferences(
  language: 'FR',
  currency: 'EUR',
  emailNotificationsEnabled: true,
);
const _incomplete = ExchangePreferences(
  language: null,
  currency: 'CAD',
  emailNotificationsEnabled: true,
);
const _loadFailure = ExchangeSettingsAccountUnavailableFailure();
const _saveFailure = ExchangeSettingsPreferencesSaveFailure();

final _states = <PreferencesState>[
  const PreferencesLoading(1), // 0
  const PreferencesLoadFailed(1, _loadFailure), // 1
  const PreferencesSignedOut(), // 2
  const PreferencesEditing(_a, _a), // 3
  const PreferencesEditing(_a, _b), // 4
  const PreferencesSaving(_a, _b, _b), // 5
  const PreferencesSaving(_a, _b, _c), // 6
  const PreferencesSaved(_b), // 7
  const PreferencesSaveFailed(_a, _b, _saveFailure), // 8
  const PreferencesEditing(_incomplete, _incomplete), // 9
];

final _table = <String, (PreferencesEvent, Map<int, PreferencesState>)>{
  'loaded': (
    const PreferencesLoaded(1, Ok(_a)),
    {0: const PreferencesEditing(_a, _a)},
  ),
  'load failed': (
    const PreferencesLoaded(1, Err(_loadFailure)),
    {0: const PreferencesLoadFailed(1, _loadFailure)},
  ),
  'load: signed out (SET-3)': (
    const PreferencesLoaded(1, Err(ExchangeSettingsNotAuthenticatedFailure())),
    {0: const PreferencesSignedOut()},
  ),
  'loaded, stale attempt': (const PreferencesLoaded(2, Ok(_a)), {}),
  'retry': (const PreferencesRetryPressed(), {1: const PreferencesLoading(2)}),
  'language chosen': (
    const PreferencesLanguageChosen('FR'),
    {
      3: const PreferencesEditing(_a, _b),
      4: const PreferencesEditing(_a, _b),
      5: const PreferencesSaving(_a, _b, _b),
      6: const PreferencesSaving(_a, _b, _c),
      7: const PreferencesEditing(_b, _b),
      8: const PreferencesEditing(_a, _b),
      9: const PreferencesEditing(
        _incomplete,
        ExchangePreferences(
          language: 'FR',
          currency: 'CAD',
          emailNotificationsEnabled: true,
        ),
      ),
    },
  ),
  'currency chosen (SET-2: an edit during a save stays a draft)': (
    const PreferencesCurrencyChosen('EUR'),
    {
      3: const PreferencesEditing(
        _a,
        ExchangePreferences(
          language: 'EN',
          currency: 'EUR',
          emailNotificationsEnabled: true,
        ),
      ),
      4: const PreferencesEditing(_a, _c),
      5: const PreferencesSaving(_a, _b, _c),
      6: const PreferencesSaving(_a, _b, _c),
      7: const PreferencesEditing(_b, _c),
      8: const PreferencesEditing(_a, _c),
      9: const PreferencesEditing(
        _incomplete,
        ExchangePreferences(
          language: null,
          currency: 'EUR',
          emailNotificationsEnabled: true,
        ),
      ),
    },
  ),
  'email toggled': (
    const PreferencesEmailToggled(true),
    {
      3: const PreferencesEditing(_a, _a),
      4: const PreferencesEditing(_a, _b),
      5: const PreferencesSaving(_a, _b, _b),
      6: const PreferencesSaving(_a, _b, _c),
      7: const PreferencesEditing(_b, _b),
      8: const PreferencesEditing(_a, _b),
      9: const PreferencesEditing(_incomplete, _incomplete),
    },
  ),
  'save pressed': (
    const PreferencesSavePressed(),
    {
      4: const PreferencesSaving(_a, _b, _b),
      8: const PreferencesSaving(_a, _b, _b),
    },
  ),
  'saved, nothing edited meanwhile': (
    const PreferencesSaveAnswered(GateAdmitted(Ok(null))),
    {5: const PreferencesSaved(_b), 6: const PreferencesEditing(_b, _c)},
  ),
  'save failed (SET-2: saved stays what the account has)': (
    const PreferencesSaveAnswered(GateAdmitted(Err(_saveFailure))),
    {
      5: const PreferencesSaveFailed(_a, _b, _saveFailure),
      6: const PreferencesSaveFailed(_a, _c, _saveFailure),
    },
  ),
  'save: signed out (SET-3)': (
    const PreferencesSaveAnswered(
      GateAdmitted(Err(ExchangeSettingsNotAuthenticatedFailure())),
    ),
    {5: const PreferencesSignedOut(), 6: const PreferencesSignedOut()},
  ),
  'save refused by the write gate': (
    const PreferencesSaveAnswered(
      GateRefused(WriteGateBusy(FinancialWriteKind.orderConfirm)),
    ),
    {
      5: const PreferencesSaveFailed(
        _a,
        _b,
        ExchangeSettingsWriteBusyFailure(),
      ),
      6: const PreferencesSaveFailed(
        _a,
        _c,
        ExchangeSettingsWriteBusyFailure(),
      ),
    },
  ),
};

void main() {
  group('every (state, event) pair', () {
    for (final MapEntry(key: name, value: (event, changes)) in _table.entries) {
      for (final (index, state) in _states.indexed) {
        test('$name from state $index', () {
          final next = transitionPreferences(state, event);
          if (changes[index] case final expected?) {
            expect(next.state, expected);
          } else {
            expect(identical(next.state, state), isTrue);
            expect(next.effects, isEmpty);
          }
        });
      }
    }
  });

  test('effects', () {
    expect(preferencesStart(signedIn: true).effects, const [
      FetchPreferences(1),
    ]);
    expect(
      preferencesStart(signedIn: false).state,
      const PreferencesSignedOut(),
    );
    expect(
      transitionPreferences(
        _states[1],
        const PreferencesRetryPressed(),
      ).effects,
      const [FetchPreferences(2)],
    );
    expect(
      transitionPreferences(_states[4], const PreferencesSavePressed()).effects,
      const [SavePreferences(_a, _b)],
    );
  });

  test('every state is reachable from the start', () {
    final seen = <Type>{};
    final queue = <PreferencesState>[preferencesStart(signedIn: true).state];
    final visited = <PreferencesState>{};
    while (queue.isNotEmpty && visited.length < 500) {
      final state = queue.removeAt(0);
      if (!visited.add(state)) continue;
      seen.add(state.runtimeType);
      final attempt = switch (state) {
        PreferencesLoading(:final attempt) ||
        PreferencesLoadFailed(:final attempt) => attempt,
        _ => 0,
      };
      for (final event in <PreferencesEvent>[
        PreferencesLoaded(attempt, const Ok(_a)),
        PreferencesLoaded(attempt, const Err(_loadFailure)),
        PreferencesLoaded(
          attempt,
          const Err(ExchangeSettingsNotAuthenticatedFailure()),
        ),
        const PreferencesRetryPressed(),
        const PreferencesLanguageChosen('FR'),
        const PreferencesCurrencyChosen('EUR'),
        const PreferencesSavePressed(),
        const PreferencesSaveAnswered(GateAdmitted(Ok(null))),
        const PreferencesSaveAnswered(GateAdmitted(Err(_saveFailure))),
      ]) {
        final next = transitionPreferences(state, event).state;
        if (!identical(next, state)) queue.add(next);
      }
    }
    expect(seen, {
      PreferencesLoading,
      PreferencesLoadFailed,
      PreferencesSignedOut,
      PreferencesEditing,
      PreferencesSaving,
      PreferencesSaved,
      PreferencesSaveFailed,
    });
  });
}
