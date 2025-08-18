import 'package:bb_mobile/core/bip85_derivations/bip85_utils.dart';
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

  static const prefix = "m/83696968'/";

  Bip85Datasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

  Future<({String derivation, String hex})> deriveHex({
    required String xprvBase58,
    required int length,
    required int index,
    String? alias,
  }) async {
    try {
      const application = Bip85ApplicationColumn.hex;

      // Ensure the xprv is valid.
      final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);

      // /!\ sensitive data: Construct the derivation path
      final derivationPath =
          "${Bip85Datasource.prefix}${application.number}'/$length'/$index'";

      final bip85Hex = bip85.toHex(
        xprv: xprv.toBase58(),
        length: length,
        index: index,
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
  }) async {
    try {
      // TODO(azad): I need to rework bip85 crate/package to use all available languages.
      const language = bip39.Language.english; // will be a param in the future
      const application = Bip85ApplicationColumn.bip39;

      // Ensure the xprv is valid.
      final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);

      // Convert the language and length to the corresponding BIP85 codes.
      final languageCode = Bip85Utils.bip39LanguageToBip85Code(language);
      final lengthCode = Bip85Utils.bip39LengthToBip85Code(length);

      // /!\ sensitive data: Construct the derivation path
      final derivationPath =
          "${Bip85Datasource.prefix}${application.number}'/$languageCode'/$lengthCode'/$index'";

      final bip85Mnemonic = bip85.toMnemonic(
        xprv: xprv.toBase58(),
        wordCount: lengthCode,
        index: index,
      );

      // Parse the bip85 generated mnemonic with bip39 mnemonic.
      final bip39Mnemonic = bip39.Mnemonic.fromSentence(
        bip85Mnemonic,
        language,
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

      return (derivation: derivationPath, mnemonic: bip39Mnemonic);
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
