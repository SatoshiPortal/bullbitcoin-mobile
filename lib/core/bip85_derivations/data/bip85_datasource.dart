import 'package:bb_mobile/core/bip85_derivations/data/bip85_derivation_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85/bip85.dart' as bip85;
import 'package:convert/convert.dart';
import 'package:drift/drift.dart';

class Bip85Datasource {
  final SqliteDatabase _sqlite;

  Bip85Datasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<({String derivation, String hex})> deriveHex({
    required String xprvBase58,
    required int length,
    required int index,
    String? alias,
  }) async {
    try {
      const application = Bip85ApplicationColumn.hex;
      final derivationPath = "${application.number}'/$length'/$index'";

      // Ensure the xprv is valid.
      final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);

      final bip85Hex = bip85.Bip85Entropy.deriveHex(xprvBase58, length, index);

      // store the derivation into sqlite
      await _store(
        Bip85DerivationModel(
          derivation: derivationPath,
          xprvFingerprint: hex.encode(xprv.fingerprint),
          alias: alias,
          status: Bip85StatusColumn.active,
          application: application,
        ),
      );

      return (derivation: derivationPath, hex: bip85Hex);
    } catch (e) {
      rethrow;
    }
  }

  Future<({String derivation, bip39.Mnemonic mnemonic})> deriveMnemonic({
    required String xprvBase58,
    required bip39.MnemonicLength length,
    required int index,
    String? alias,
    bip39.Language language = bip39.Language.english,
  }) async {
    try {
      const application = Bip85ApplicationColumn.bip39;
      final derivationPath =
          "${application.number}'/${language.toBip85Code()}'/${length.toBip85Code()}'/$index'";

      // Ensure the xprv is valid.
      final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);

      final bip85Mnemonic = bip85.Bip85Entropy.deriveMnemonic(
        xprvBase58,
        language,
        length,
        index,
      );

      // store the derivation into sqlite
      await _store(
        Bip85DerivationModel(
          derivation: derivationPath,
          xprvFingerprint: hex.encode(xprv.fingerprint),
          alias: alias,
          status: Bip85StatusColumn.active,
          application: application,
        ),
      );

      return (derivation: derivationPath, mnemonic: bip85Mnemonic);
    } catch (e) {
      rethrow;
    }
  }

  Future<Bip85DerivationModel?> fetch(String derivation) async {
    final row =
        await _sqlite.managers.bip85Derivations
            .filter((b) => b.derivation(derivation))
            .getSingleOrNull();

    return row != null ? Bip85DerivationModel.fromSqlite(row) : null;
  }

  Future<int> fetchNextIndexForApplication(
    Bip85ApplicationColumn application,
  ) async {
    final rows =
        await _sqlite.managers.bip85Derivations
            .filter((b) => b.application(application))
            .get();

    final models =
        rows.map((row) => Bip85DerivationModel.fromSqlite(row)).toList();

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

  Future<void> revoke(String derivation) async {
    try {
      await _sqlite.managers.bip85Derivations
          .filter((b) => b.derivation(derivation))
          .update((b) => b(status: const Value(Bip85StatusColumn.revoked)));
    } catch (e) {
      rethrow;
    }
  }

  // We should not use _store without properly formatting the derivation path.
  Future<void> _store(Bip85DerivationModel bip85) async {
    try {
      await _sqlite.managers.bip85Derivations.create(
        (b) => b(
          derivation: bip85.derivation,
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
