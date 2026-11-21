import 'package:preferences/testing.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart'
    show Environment, ExchangeTestnetBasicAuthPreferences;
import 'package:preferences/recoverbull_table.drift.dart';
import 'package:preferences/storage.dart';
import 'package:primitives/primitives.dart' show Ok;

void main() {
  late SqliteDatabase database;
  late PreferencesDao dao;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    dao = database.preferencesDao;
  });

  tearDown(() => database.close());

  test(
    'dismissals use the existing table and refresh the same record',
    () async {
      final dismissals = PreferencesTesting.fromDao(dao).announcementDismissals;
      final first = DateTime.utc(2026, 11, 19);
      final latest = DateTime.utc(2026, 11, 21);

      expect(
        (await dismissals.read()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        ),
        isEmpty,
      );
      expect(await dismissals.dismiss('sample', first), isA<Ok>());
      expect(await dismissals.dismiss('sample', latest), isA<Ok>());

      expect(
        (await dismissals.read()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        ),
        [(id: 'sample', dismissedAt: latest)],
      );
      final row = await database.managers.dismissedAnnouncements.getSingle();
      expect(row.announcementId, 'sample');
      expect(row.dismissedAt, latest);
    },
  );

  test('RecoverBull reads the existing server and permission row', () async {
    final preferences = PreferencesTesting.fromDao(dao).recoverBull;
    final seeded = (await preferences.read()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    expect(seeded?.permissionGranted, isFalse);

    await database
        .into(database.recoverbull)
        .insertOnConflictUpdate(
          const RecoverbullRow(
            id: 1,
            url: 'https://example.test',
            isPermissionGranted: true,
          ),
        );
    expect(
      (await preferences.read()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      ),
      (server: Uri.parse('https://example.test'), permissionGranted: true),
    );
  });

  test(
    'exchange testnet credentials stay in the existing settings row',
    () async {
      final settings = PreferencesTesting.fromDao(dao);
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
      expect(row.environment, 'testnet');
      expect(row.exchangeTestnetBasicAuthUsername, isNull);
      expect(row.exchangeTestnetBasicAuthPassword, isNull);
    },
  );
}
