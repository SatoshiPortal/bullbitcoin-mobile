import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';

void main() {
  late PreferencesDatabase database;
  late Preferences preferences;

  setUp(() async {
    database = PreferencesDatabase(NativeDatabase.memory());
    // A row written without the column, as a pre-existing owner row is.
    await database.customStatement(
      'INSERT INTO settings (id, environment, bitcoin_unit, language, '
      'currency, hide_amounts, is_superuser) '
      "VALUES (1, 'mainnet', 'sats', 'unitedStatesEnglish', 'USD', 0, 0)",
    );
    preferences = PreferencesTesting.fromDao(PreferencesDao(database));
    addTearDown(() async {
      await preferences.close();
      await database.close();
    });
  });

  bool valueOf(Result<bool, PreferencesFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => fail('expected Ok, got $result'),
  };

  test('payment animations are shown by default', () async {
    expect(valueOf(await preferences.readShowPaymentAnimations()), isTrue);
    final settings = switch (await preferences.fetch()) {
      Ok(:final value) => value,
      Err() => fail('fetch failed'),
    };
    expect(settings.showPaymentAnimations, isTrue);
  });

  test('the preference round-trips through storage', () async {
    expect(await preferences.setShowPaymentAnimations(false), isA<Ok>());
    expect(valueOf(await preferences.readShowPaymentAnimations()), isFalse);
    final settings = switch (await preferences.fetch()) {
      Ok(:final value) => value,
      Err() => fail('fetch failed'),
    };
    expect(settings.showPaymentAnimations, isFalse);

    expect(await preferences.setShowPaymentAnimations(true), isA<Ok>());
    expect(valueOf(await preferences.readShowPaymentAnimations()), isTrue);
  });

  test('writing without a settings row is a missing failure', () async {
    await database.customStatement('DELETE FROM settings');

    final result = await preferences.setShowPaymentAnimations(false);

    expect(
      result,
      isA<Err<void, PreferencesFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<PreferencesMissingFailure>(),
      ),
    );
  });
}
