import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:drift/drift.dart' show Value;

class SettingsRepository {
  final SqliteDatasource _sqlite;

  SettingsRepository({required SqliteDatasource sqliteDatasource})
      : _sqlite = sqliteDatasource;

  Future<void> store({
    required int id,
    required Environment environment,
    required BitcoinUnit bitcoinUnit,
    required String currency,
    required Language language,
    required bool hideAmounts,
  }) async {
    await _sqlite.managers.settings.create(
      (s) => s(
        id: Value(id), // not needed
        environment: environment.name,
        bitcoinUnit: bitcoinUnit.name,
        currency: currency,
        language: language.name,
        hideAmounts: hideAmounts,
      ),
    );
  }

  Future<SettingsEntity> fetch() async {
    final s =
        await _sqlite.managers.settings.filter((f) => f.id(1)).getSingle();

    return SettingsEntity(
      environment: Environment.fromName(s.environment),
      bitcoinUnit: BitcoinUnit.fromName(s.bitcoinUnit),
      currencyCode: s.currency,
      language: Language.fromName(s.language) ?? Language.unitedStatesEnglish,
      hideAmounts: s.hideAmounts,
    );
  }

  Future<void> setEnvironment(Environment env) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), environment: Value(env.name)),
    );
  }

  Future<void> setBitcoinUnit(BitcoinUnit bitcoinUnit) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), bitcoinUnit: Value(bitcoinUnit.name)),
    );
  }

  Future<void> setLanguage(Language language) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), language: Value(language.name)),
    );
  }

  Future<void> setCurrency(String currencyCode) async {
    await _sqlite.managers.settings.update(
      (f) => f(id: const Value(1), currency: Value(currencyCode)),
    );
  }

  Future<void> setHideAmounts(bool hide) async {
    await _sqlite.managers.settings
        .update((f) => f(id: const Value(1), hideAmounts: Value(hide)));
  }
}
