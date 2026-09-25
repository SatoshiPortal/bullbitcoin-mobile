import 'package:bb_mobile/core/bip85/data/bip85_derivation_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:drift/drift.dart';

class Bip85Datasource {
  final SqliteDatabase _sqlite;

  Bip85Datasource({required this._sqlite});

  /// Records a HEX derivation the `secrets` package has already performed, under the path it has always been filed by. Nothing here derives: the xprv no longer leaves the package.
  Future<String> recordHex({
    required String xprvFingerprint,
    required int length,
    required int index,
    String? alias,
  }) async {
    try {
      const application = Bip85ApplicationColumn.hex;
      final derivationPath = "${application.number}'/$length'/$index'";
      await _store(
        Bip85DerivationModel(
          path: derivationPath,
          xprvFingerprint: xprvFingerprint,
          alias: alias,
          status: Bip85StatusColumn.active,
          application: application,
        ),
      );

      return derivationPath;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> recordMnemonic({
    required String xprvFingerprint,
    required bip39.MnemonicLength length,
    required int index,
    String? alias,
    bip39.Language language = bip39.Language.english,
  }) async {
    try {
      const application = Bip85ApplicationColumn.bip39;
      final derivationPath =
          "${application.number}'/${language.toBip85Code()}'/${length.toBip85Code()}'/$index'";
      await _store(
        Bip85DerivationModel(
          path: derivationPath,
          xprvFingerprint: xprvFingerprint,
          alias: alias,
          status: Bip85StatusColumn.active,
          application: application,
        ),
      );

      return derivationPath;
    } catch (e) {
      rethrow;
    }
  }

  Future<Bip85DerivationModel?> fetch(String path) async {
    final row = await _sqlite.managers.bip85Derivations
        .filter((b) => b.path(path))
        .getSingleOrNull();

    return row != null ? Bip85DerivationModel.fromSqlite(row) : null;
  }

  Future<int> fetchNextIndexForApplication(
    Bip85ApplicationColumn application,
  ) async {
    final rows = await _sqlite.managers.bip85Derivations
        .filter((b) => b.application(application))
        .get();

    final models = rows
        .map((row) => Bip85DerivationModel.fromSqlite(row))
        .toList();

    int nextIndex = 0;
    for (final model in models) {
      if (model.index >= nextIndex) nextIndex = model.index + 1;
    }

    return nextIndex;
  }

  Future<List<Bip85DerivationModel>> fetchAll() async {
    try {
      final rows = await _sqlite.managers.bip85Derivations.get();
      return rows.map((row) => Bip85DerivationModel.fromSqlite(row)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> revoke(String path) async {
    try {
      await _sqlite.managers.bip85Derivations
          .filter((b) => b.path(path))
          .update((b) => b(status: const Value(Bip85StatusColumn.revoked)));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> activate(String path) async {
    try {
      await _sqlite.managers.bip85Derivations
          .filter((b) => b.path(path))
          .update((b) => b(status: const Value(Bip85StatusColumn.active)));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> alias(String path, String alias) async {
    try {
      await _sqlite.managers.bip85Derivations
          .filter((b) => b.path(path))
          .update((b) => b(alias: Value(alias)));
    } catch (e) {
      rethrow;
    }
  }

  // We should not use _store without properly formatting the derivation path.
  Future<void> _store(Bip85DerivationModel bip85) async {
    try {
      await _sqlite.managers.bip85Derivations.create(
        (b) => b(
          path: bip85.path,
          xprvFingerprint: bip85.xprvFingerprint,
          alias: Value(bip85.alias),
          status: bip85.status,
          application: bip85.application,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }
}
