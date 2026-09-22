import 'package:bb_mobile/core/bip85/data/bip85_derivation_model.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
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

  /// Invalidates cached facts; consumers reread after the transaction ends.
  Stream<void> get changes => _sqlite
      .tableUpdates(TableUpdateQuery.onTable(_sqlite.bip85Derivations))
      .map((_) {});

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

      final bip85Hex = bip85.Bip85Entropy.deriveHex(
        xprvBase58: xprvBase58,
        numBytes: length,
        index: index,
      );

      // store the derivation into sqlite
      await _store(
        Bip85DerivationModel(
          path: derivationPath,
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
      if (Bip85Reservations.isReservedPath(derivationPath)) {
        throw const FormatException('This BIP85 path is reserved for backups');
      }

      // Ensure the xprv is valid.
      final xprv = bip32.Bip32Keys.fromBase58(xprvBase58);

      final bip85Mnemonic = bip85.Bip85Entropy.deriveMnemonic(
        xprvBase58: xprvBase58,
        language: language,
        length: length,
        index: index,
      );

      // store the derivation into sqlite
      await _store(
        Bip85DerivationModel(
          path: derivationPath,
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

  /// Adds public recovery metadata only. Existing records remain owned by
  /// their original seed and keep local aliases and revocation decisions.
  Future<bool> restorePublicRecord(Bip85DerivationModel record) =>
      _sqlite.transaction(() async {
        final path = record.path;
        final parts = path.split('/');
        if (path.length > 200 ||
            parts.length < 2 ||
            parts.any(
              (part) =>
                  !RegExp(r"^(0|[1-9][0-9]*)'$").hasMatch(part) ||
                  (int.tryParse(part.replaceAll("'", '')) ??
                          (Bip85Reservations.maxIndex + 1)) >
                      Bip85Reservations.maxIndex,
            ) ||
            parts.first != "${record.application.number}'" ||
            !RegExp(r'^[0-9a-f]{8}$').hasMatch(record.xprvFingerprint) ||
            Bip85Reservations.isReservedPath(path)) {
          throw const FormatException('Invalid public BIP85 record');
        }
        final existing = await fetch(path);
        if (existing != null) {
          return existing.xprvFingerprint == record.xprvFingerprint &&
              existing.application == record.application;
        }
        await _store(record);
        return true;
      });

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
