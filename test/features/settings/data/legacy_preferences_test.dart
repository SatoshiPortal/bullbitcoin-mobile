import 'package:preferences/testing.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart'
    show Environment, ExchangeTestnetBasicAuthPreferences;
import 'package:primitives/primitives.dart' show Ok;

import '../../../support/preferences_database.dart';

void main() {
  late SqliteDatabase database;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('RecoverBull reads the owner permission without a URL', () async {
    final owner = await createPreferencesDatabase();
    addTearDown(owner.close);
    await owner.customStatement('INSERT INTO recoverbull VALUES (1, 0)');
    final settings = PreferencesTesting.fromDatabases(
      owner: owner,
      legacy: database,
    );
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

  test(
    'exchange testnet credentials stay in the existing settings row',
    () async {
      final owner = await createPreferencesDatabase();
      addTearDown(owner.close);
      final settings = PreferencesTesting.fromDatabases(
        owner: owner,
        legacy: database,
      );
      addTearDown(settings.close);
      final ExchangeTestnetBasicAuthPreferences auth = settings;

      expect(
        await auth.setExchangeTestnetBasicAuth(
          username: 'example',
          password: 'example',
        ),
        isA<Ok>(),
      );
      expect(
        ((await auth.readExchangeWebPreferences()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        )).exchangeTestnetBasicAuthPassword,
        isNull,
      );
      expect(await settings.setIsSuperuser(true), isA<Ok>());
      expect(await settings.setIsDevMode(true), isA<Ok>());
      expect(await settings.setEnvironment(Environment.testnet), isA<Ok>());
      expect(
        (await auth.readExchangeWebPreferences()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        ),
        (
          environment: Environment.testnet,
          exchangeTestnetBasicAuthUsername: 'example',
          exchangeTestnetBasicAuthPassword: 'example',
        ),
      );
      expect(await auth.setExchangeTestnetBasicAuth(), isA<Ok>());

      final row = await database.managers.settings.getSingle();
      expect(
        (await owner.managers.ownerSettings.getSingle()).environment,
        'testnet',
      );
      expect(row.environment, 'mainnet');
      expect(row.exchangeTestnetBasicAuthUsername, isNull);
      expect(row.exchangeTestnetBasicAuthPassword, isNull);
    },
  );
}
