import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/migration.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Wizard extends Mock implements WizardRepository {}

class _Intervals extends Mock implements BackgroundSyncIntervalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late NativeFileGate gate;
  late File ownerFile;
  late LegacySourceStore<SqliteDatabase> source;
  late DatabaseKeys keys;
  late RuntimeAdmission admission;
  late SqliteDatabase legacy;
  late Preferences preferences;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('preferences-routing-');
    FakeSecureStoragePlatform().install();
    keys = Secrets(scratchDirectory: () async => directory.path)
        .databaseKeys(module: 'preferences');
    gate = NativeFileGate(File('${directory.path}/gate'));
    ownerFile = File('${directory.path}/preferences.sqlite');
    source = LegacySourceStore(
      source: LegacySource(File('${directory.path}/legacy.sqlite'), 16),
      create: SqliteDatabase.new,
    );
    final seed = SqliteDatabase(NativeDatabase(source.source.file));
    await seed.customSelect('SELECT * FROM settings').get();
    await seed.customStatement(
      "UPDATE settings SET environment='testnet',is_superuser=1,is_dev_mode_enabled=1,exchange_testnet_basic_auth_username='synthetic-user',exchange_testnet_basic_auth_password='synthetic-password'",
    );
    await seed.close();
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    final participant = PreferencesImport(file: ownerFile, testingKeys: keys);
    final owner = (await participant.prepare(
      exclusive,
      OwnerOrigin.legacy,
    ) as Ok<PreparedOwner, LegacyImportFailure>).value;
    expect(await owner.importLegacy(source.source), isA<Ok>());
    await exclusive.close();
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    legacy = await source.open(admission);
    preferences = (await PreferencesTesting.open(
      file: ownerFile,
      admission: admission,
      legacyDatabase: legacy,
      keys: keys,
    ) as Ok<Preferences, PreferencesFailure>).value;
  });
  tearDown(() async {
    await preferences.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  test(
    'owner writes and web environment never use stale legacy preferences',
    () async {
      final before =
          (await legacy.customSelect('SELECT * FROM settings').getSingle())
              .data;
      expect(await preferences.setEnvironment(Environment.mainnet), isA<Ok>());
      expect(await preferences.setCurrency('EUR'), isA<Ok>());
      expect(
        (await legacy.customSelect('SELECT * FROM settings').getSingle()).data,
        before,
      );
      final web =
          (await preferences.readExchangeWebPreferences()
                  as Ok<ExchangeWebPreferences, PreferencesFailure>)
              .value;
      expect(web.environment, Environment.mainnet);
      expect(web.exchangeTestnetBasicAuthUsername, isNull);
      expect(web.exchangeTestnetBasicAuthPassword, isNull);
      expect(await preferences.setEnvironment(Environment.testnet), isA<Ok>());
      final testnet =
          (await preferences.readExchangeWebPreferences()
                  as Ok<ExchangeWebPreferences, PreferencesFailure>)
              .value;
      expect(testnet.exchangeTestnetBasicAuthUsername, 'synthetic-user');
      expect(testnet.exchangeTestnetBasicAuthPassword, 'synthetic-password');
      expect(
        await preferences.setExchangeTestnetBasicAuth(
          username: 'updated-synthetic',
          password: null,
        ),
        isA<Ok>(),
      );
      expect(
        (await preferences.readCurrency() as Ok<String, PreferencesFailure>)
            .value,
        'EUR',
      );
      final after =
          (await legacy.customSelect('SELECT * FROM settings').getSingle())
              .data;
      expect(after, {
        ...before,
        'exchange_testnet_basic_auth_username': 'updated-synthetic',
        'exchange_testnet_basic_auth_password': null,
      });
    },
  );

  test(
    'owner-only readers do not depend on the legacy credentials row',
    () async {
      await legacy.customStatement('DELETE FROM settings');
      expect(
        await preferences.fetch(),
        isA<Ok<SettingsEntity, PreferencesFailure>>().having(
          (result) => result.value.environment,
          'owner environment',
          Environment.testnet,
        ),
      );
      expect(
        await preferences.readExchangeWebPreferences(),
        isA<Err<ExchangeWebPreferences, PreferencesFailure>>().having(
          (result) => result.failure,
          'missing legacy credentials row',
          isA<PreferencesMissingFailure>(),
        ),
      );
    },
  );

  test(
    'display watcher sees owner updates without changing legacy settings',
    () async {
      final updates = StreamIterator(preferences.watchDisplayPreferences());
      addTearDown(updates.cancel);
      expect(await updates.moveNext(), isTrue);
      expect(await preferences.setCurrency('JPY'), isA<Ok>());
      expect(await updates.moveNext(), isTrue);
      expect(
        updates.current,
        isA<Ok<AmountDisplayPreferences, PreferencesFailure>>().having(
          (r) => r.value.currencyCode,
          'currency',
          'JPY',
        ),
      );
      expect(
        (await legacy.customSelect('SELECT currency FROM settings').getSingle())
            .read<String>('currency'),
        'USD',
      );
    },
  );

  test('wizard commits touched fields only to owner', () async {
    final wizard = _Wizard();
    const choices = WizardChoices(
      defaultCurrency: 'CAD',
      touched: {WizardField.defaultCurrency},
    );
    when(wizard.readPending).thenAnswer((_) async => choices);
    when(wizard.clearPending).thenAnswer((_) async {});
    when(wizard.markComplete).thenAnswer((_) async {});
    final apply = ApplyPendingWizardChoicesUsecase(
      wizardRepository: wizard,
      settingsRepository: preferences,
      intervals: _Intervals(),
    );
    await apply.execute();
    verify(wizard.clearPending).called(1);
    expect(
      (await preferences.readCurrency() as Ok<String, PreferencesFailure>)
          .value,
      'CAD',
    );
    expect(
      (await legacy.customSelect('SELECT currency FROM settings').getSingle())
          .read<String>('currency'),
      'USD',
    );
  });

  test(
    'borrowed legacy connection survives capability close; lease covers both',
    () async {
      final paused = preferences.currencyChangeStream.listen((_) {})..pause();
      addTearDown(paused.cancel);
      await preferences.close().timeout(const Duration(seconds: 1));
      expect(
        (await legacy.customSelect('SELECT 1 AS alive').getSingle()).read<int>(
          'alive',
        ),
        1,
      );
      await expectLater(
        gate.acquire(exclusive: true, timeout: Duration.zero),
        throwsA(isA<LifecycleException>()),
      );
      await admission.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
    },
  );

  test(
    'RecoverBull reads owned history even after legacy projection changes',
    () async {
      final before = await preferences.recoverBull.read();
      expect(before, isA<Ok>());
      await legacy.customStatement(
        "UPDATE recoverbull SET url='https://changed-legacy.invalid',is_permission_granted=1",
      );
      final after = await preferences.recoverBull.read();
      expect(
        after.fold((value) => value, (_) => null),
        before.fold((value) => value, (_) => null),
      );
    },
  );

  test(
    'RecoverBull runtime saves permissions separately from each other',
    () async {
      expect(
        await preferences.recoverBull.setPermission(true),
        isA<Ok<void, PreferencesFailure>>(),
      );
      expect(
        (await preferences.recoverBull.read(
          regtest: true,
        ) as Ok<bool?, PreferencesFailure>).value,
        isFalse,
      );
      expect(
        await preferences.recoverBull.setPermission(true, regtest: true),
        isA<Err<void, PreferencesFailure>>().having(
          (result) => result.failure,
          'inactive regtest family',
          isA<PreferencesContextChangedFailure>(),
        ),
      );
      expect(await preferences.setEnvironment(Environment.regtest), isA<Ok>());
      expect(
        await preferences.recoverBull.setPermission(true, regtest: true),
        isA<Ok<void, PreferencesFailure>>(),
      );
      expect(
        await preferences.recoverBull.setPermission(false),
        isA<Err<void, PreferencesFailure>>().having(
          (result) => result.failure,
          'inactive normal family',
          isA<PreferencesContextChangedFailure>(),
        ),
      );
      expect(await preferences.setEnvironment(Environment.testnet), isA<Ok>());
      expect(
        await preferences.recoverBull.setPermission(false),
        isA<Ok<void, PreferencesFailure>>(),
      );
      expect(
        (await preferences.recoverBull.read(
          regtest: true,
        ) as Ok<bool?, PreferencesFailure>).value,
        isTrue,
      );
      expect(
        (await preferences.recoverBull.read() as Ok<bool?, PreferencesFailure>)
            .value,
        isFalse,
      );
    },
  );

  test('missing legacy credential row fails explicitly without seeding either store', () async {
    await legacy.customStatement('DELETE FROM settings');
    expect(
      await preferences.setExchangeTestnetBasicAuth(username: 'synthetic'),
      isA<Err>(),
    );
    expect(await preferences.readExchangeWebPreferences(), isA<Err>());
    expect(
      (await preferences.readActiveEnvironment()
              as Ok<Environment, PreferencesFailure>)
          .value,
      Environment.testnet,
    );
    expect(await legacy.customSelect('SELECT * FROM settings').get(), isEmpty);
  });
}
