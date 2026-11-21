import 'dart:io';

import 'package:preferences/storage.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_amount_input_mode_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../migrations_test/bull_database/generated/schema_v15.dart'
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
        var database = SqliteDatabase(NativeDatabase(file));
        var datasource = PreferencesDao(database);
        var reader = SettingsRepositoryImpl(settingsDatasource: datasource);
        expect((await reader.fetch()).startAmountsInFiat, isFalse);
        final original = await reader.fetch();
        var setter = SetAmountInputModeUsecase(reader);
        expect(
          await setter.execute(fiat: true),
          isA<Ok<void, SettingsFailure>>(),
        );
        await reader.close();
        await database.close();
        database = SqliteDatabase(NativeDatabase(file));
        addTearDown(database.close);
        datasource = PreferencesDao(database);
        reader = SettingsRepositoryImpl(settingsDatasource: datasource);
        addTearDown(reader.close);
        final saved = await reader.fetch();
        expect(saved.startAmountsInFiat, isTrue);
        expect(saved.bitcoinUnit, original.bitcoinUnit);
        expect(saved.currencyCode, original.currencyCode);
        setter = SetAmountInputModeUsecase(reader);
        expect(
          await setter.execute(fiat: false),
          isA<Ok<void, SettingsFailure>>(),
        );
        expect((await reader.fetch()).startAmountsInFiat, isFalse);
        expect(SqliteDatabase.currentSchemaVersion, 16);
      },
    );
  }

  test(
    'storage failures are modeled and programmer errors propagate',
    () async {
      final datasource = _Datasource();
      final setter = SetAmountInputModeUsecase(
        SettingsRepositoryImpl(settingsDatasource: datasource),
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
