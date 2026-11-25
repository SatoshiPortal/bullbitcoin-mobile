import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/testing.dart';

import '../../../support/preferences_database.dart';

void main() {
  test('RecoverBull reads the owner permission without a URL', () async {
    final owner = await createPreferencesDatabase();
    addTearDown(owner.close);
    await owner.customStatement('INSERT INTO recoverbull VALUES (1, 0)');
    final settings = PreferencesTesting.fromDao(PreferencesDao(owner));
    addTearDown(settings.close);
    final preferences = settings.recoverBull;
    final seeded = (await preferences.read()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    expect(seeded, isFalse);
    await owner.customStatement(
      'UPDATE recoverbull SET is_permission_granted = 1 WHERE id = 1',
    );
    expect(
      (await preferences.read()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      ),
      isTrue,
    );
  });
}
