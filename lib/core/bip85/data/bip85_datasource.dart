import 'package:bb_mobile/core/bip85/data/bip85_derivation_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart';
import 'package:drift/drift.dart';

class Bip85Datasource {
  final SqliteDatabase _sqlite;

  Bip85Datasource({required this._sqlite});

  Future<({String derivation, String hex})> deriveHex({
    required String xprvBase58,
    required int length,
    required int index,
    String? alias,
  }) async {
    const application = Bip85ApplicationColumn.hex;
    final derivationPath = "${application.number}'/$length'/$index'";
    final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);
    final derived = bip85.Bip85Entropy.deriveHex(
      xprvBase58: xprvBase58,
      numBytes: length,
      index: index,
    );
    await _store(
      Bip85DerivationModel(
        path: derivationPath,
        xprvFingerprint: hex.encode(xprv.fingerprint),
        alias: alias,
        status: Bip85StatusColumn.active,
        application: application,
      ),
    );
    return (derivation: derivationPath, hex: derived);
  }

  Future<({String derivation, bip39.Mnemonic mnemonic})> deriveMnemonic({
    required String xprvBase58,
    required bip39.MnemonicLength length,
    required int index,
    String? alias,
    bip39.Language language = bip39.Language.english,
  }) async {
    final derived = _deriveMnemonic(
      xprvBase58: xprvBase58,
      length: length,
      index: index,
      language: language,
    );
    await _store(
      Bip85DerivationModel(
        path: derived.derivation,
        xprvFingerprint: derived.xprvFingerprint,
        alias: alias,
        status: Bip85StatusColumn.active,
        application: Bip85ApplicationColumn.bip39,
      ),
    );
    return (derivation: derived.derivation, mnemonic: derived.mnemonic);
  }

  ({String derivation, bip39.Mnemonic mnemonic}) deriveMnemonicPreview({
    required String xprvBase58,
    required bip39.MnemonicLength length,
    required int index,
    bip39.Language language = bip39.Language.english,
  }) {
    final derived = _deriveMnemonic(
      xprvBase58: xprvBase58,
      length: length,
      index: index,
      language: language,
    );
    return (derivation: derived.derivation, mnemonic: derived.mnemonic);
  }

  Future<Bip85DerivationModel?> fetch(String path) async {
    final row = await _sqlite.managers.bip85Derivations
        .filter((b) => b.path(path))
        .getSingleOrNull();

    return row != null ? Bip85DerivationModel.fromSqlite(row) : null;
  }

  Future<int> fetchNextIndexForApplication(
    Bip85ApplicationColumn application, {
    Set<int> excludedIndices = const {},
  }) async {
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

    while (excludedIndices.contains(nextIndex)) {
      nextIndex++;
    }

    return nextIndex;
  }

  Future<List<Bip85DerivationModel>> fetchAll() async {
    final rows = await _sqlite.managers.bip85Derivations.get();
    return rows.map(Bip85DerivationModel.fromSqlite).toList();
  }

  Future<void> revoke(String path) async {
    await _sqlite.managers.bip85Derivations
        .filter((b) => b.path(path))
        .update((b) => b(status: const Value(Bip85StatusColumn.revoked)));
  }

  Future<void> activate(String path) async {
    await _sqlite.managers.bip85Derivations
        .filter((b) => b.path(path))
        .update((b) => b(status: const Value(Bip85StatusColumn.active)));
  }

  Future<void> alias(String path, String alias) async {
    await _sqlite.managers.bip85Derivations
        .filter((b) => b.path(path))
        .update((b) => b(alias: Value(alias)));
  }

  Future<void> _store(Bip85DerivationModel derivation) async {
    final existing = await _sqlite.managers.bip85Derivations
        .filter((row) => row.path(derivation.path))
        .getSingleOrNull();
    await _sqlite.managers.bip85Derivations.create(
      (row) => row(
        path: derivation.path,
        xprvFingerprint: derivation.xprvFingerprint,
        alias: Value(derivation.alias),
        status: derivation.status,
        application: derivation.application,
      ),
      mode:
          existing != null &&
              existing.xprvFingerprint != derivation.xprvFingerprint
          ? InsertMode.insertOrReplace
          : InsertMode.insert,
    );
  }

  ({String derivation, bip39.Mnemonic mnemonic, String xprvFingerprint})
  _deriveMnemonic({
    required String xprvBase58,
    required bip39.MnemonicLength length,
    required int index,
    required bip39.Language language,
  }) {
    const application = Bip85ApplicationColumn.bip39;
    final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);
    return (
      derivation:
          "${application.number}'/${language.toBip85Code()}'/${length.toBip85Code()}'/$index'",
      mnemonic: bip85.Bip85Entropy.deriveMnemonic(
        xprvBase58: xprvBase58,
        language: language,
        length: length,
        index: index,
      ),
      xprvFingerprint: hex.encode(xprv.fingerprint),
    );
  }
}
