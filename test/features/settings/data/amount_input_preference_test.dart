import 'package:preferences/testing.dart';

import 'dart:io';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:settings/testing.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart'
    show recoverBullDefaultServerUrl;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/migration.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secrets;
import 'package:secrets/testing.dart';

import '../../../../packages/legacy_storage/test/migrations_test/bull_database/generated/schema_v15.dart'
    as v15;

class _Datasource extends Mock implements PreferencesDao {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final upgrade in [false, true]) {
    test(
      'amount input preference survives reopen and Undo, upgrade=$upgrade',
      () async {
        final dir = await Directory.systemTemp.createTemp('amount_preference');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/settings.sqlite');
        if (upgrade) {
          final old = v15.DatabaseAtV15(NativeDatabase(file));
          await old.customSelect('SELECT 1').get();
          await old.customStatement(
            "INSERT INTO settings (environment, bitcoin_unit, language, currency, hide_amounts, is_superuser) VALUES ('mainnet', 'sats', 'unitedStatesEnglish', 'CAD', 0, 0)",
          );
          await old.close();
        }
        FakeSecureStoragePlatform().install();
        final keys = Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => dir.path,
        ).databaseKeys(module: 'preferences');
        final source = LegacySourceStore(
          source: LegacySource(file, SqliteDatabase.currentSchemaVersion),
          create: SqliteDatabase.new,
        );
        final ownerFile = File('${dir.path}/owner.sqlite');
        final cutover = StorageCutover(
          directory: Directory('${dir.path}/coordination'),
          legacy: source,
          expectedOwners: splitV1Owners,
          participants: [
            PreferencesImport(
              file: ownerFile,
              defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
              testingKeys: keys,
            ),
          ],
        );
        Future<Preferences> open(RuntimeAdmission admission) async {
          addTearDown(admission.close);
          final result = await PreferencesTesting.open(
            file: ownerFile,
            admission: admission,
            keys: keys,
          );
          final reader = (result as Ok<Preferences, PreferencesFailure>).value;
          addTearDown(reader.close);
          return reader;
        }

        final initial =
            (await cutover.prepare()
                    as Ok<RuntimeAdmission, LegacyImportFailure>)
                .value;
        var reader = await open(initial);
        expect(
          ((await reader.fetch()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          )).startAmountsInFiat,
          isFalse,
        );
        final original = (await reader.fetch()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        );
        var setter = SetAmountInputModeUsecase(reader);
        expect(
          await setter.execute(fiat: true),
          isA<Ok<void, SettingsFailure>>(),
        );
        await reader.close();
        await initial.close();
        reader = await open(
          (await cutover.admit() as Ok<RuntimeAdmission, LegacyImportFailure>)
              .value,
        );
        final saved = (await reader.fetch()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        );
        expect(saved.startAmountsInFiat, isTrue);
        expect(saved.bitcoinUnit, original.bitcoinUnit);
        expect(saved.currencyCode, original.currencyCode);
        setter = SetAmountInputModeUsecase(reader);
        expect(
          await setter.execute(fiat: false),
          isA<Ok<void, SettingsFailure>>(),
        );
        expect(
          ((await reader.fetch()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          )).startAmountsInFiat,
          isFalse,
        );
        expect(SqliteDatabase.currentSchemaVersion, 16);
      },
    );
  }

  test(
    'storage failures are modeled and programmer errors propagate',
    () async {
      final datasource = _Datasource();
      final setter = SetAmountInputModeUsecase(
        PreferencesTesting.fromDao(datasource),
      );
      when(() => datasource.setStartAmountsInFiat(true))
          .thenThrow(Exception('private database reason'));
      final result = await setter.execute(fiat: true);
      expect(result, isA<Err<void, SettingsFailure>>());
      switch (result) {
        case Err(:final failure):
          expect(failure, isA<SettingsStorageFailure>());
          expect(
            failure.logMessage,
            isNot(contains('private database reason')),
          );
        case Ok():
          fail('A failed write must not report success');
      }
      when(() => datasource.setStartAmountsInFiat(true))
          .thenThrow(StateError('programmer bug'));
      await expectLater(setter.execute(fiat: true), throwsStateError);
    },
  );
}
