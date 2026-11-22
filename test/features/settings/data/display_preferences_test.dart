import 'package:preferences/preferences.dart';

import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok, Err, Result;

void main() {
  test(
    'display preferences emit persisted defaults and subsequent writes',
    () async {
      final database = SqliteDatabase(NativeDatabase.memory());
      final repository = Preferences.open(database: database);
      final preferences = StreamIterator(repository.watchDisplayPreferences());
      addTearDown(() async {
        await preferences.cancel();
        await repository.close();
        await database.close();
      });

      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current), (
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        hideAmounts: false,
      ));

      expect(await repository.setBitcoinUnit(BitcoinUnit.btc), isA<Ok>());
      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current).bitcoinUnit, BitcoinUnit.btc);

      expect(await repository.setCurrency('CAD'), isA<Ok>());
      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current).currencyCode, 'CAD');

      expect(await repository.setHideAmounts(true), isA<Ok>());
      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current), (
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
        hideAmounts: true,
      ));
    },
  );

  test(
    'display preferences recover after a missing row or unsupported unit',
    () async {
      final database = SqliteDatabase(NativeDatabase.memory());
      final repository = Preferences.open(database: database);
      final preferences = StreamIterator(repository.watchDisplayPreferences());
      addTearDown(() async {
        await preferences.cancel();
        await repository.close();
        await database.close();
      });

      final stored = await database.managers.settings.getSingle();
      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current), (
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        hideAmounts: false,
      ));

      await database.delete(database.settings).go();
      expect(await preferences.moveNext(), isTrue);
      expect(
        preferences.current,
        isA<Err<AmountDisplayPreferences, PreferencesFailure>>(),
      );

      await database.into(database.settings).insert(stored);
      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current), (
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        hideAmounts: false,
      ));

      await database
          .update(database.settings)
          .replace(stored.copyWith(bitcoinUnit: 'unknown-unit'));
      expect(await preferences.moveNext(), isTrue);
      expect(
        preferences.current,
        isA<Err<AmountDisplayPreferences, PreferencesFailure>>(),
      );

      await database.update(database.settings).replace(stored);
      expect(await preferences.moveNext(), isTrue);
      expect(_value(preferences.current).bitcoinUnit, BitcoinUnit.sats);
    },
  );
}

AmountDisplayPreferences _value(
  Result<AmountDisplayPreferences, PreferencesFailure> result,
) => result.fold(
  (value) => value,
  (failure) => fail('Unexpected preference failure: $failure'),
);
