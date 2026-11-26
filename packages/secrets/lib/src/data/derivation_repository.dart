import 'package:meta/meta.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import '../domain/recorded_derivation.dart';
import 'boundary.dart';
import 'secrets_database.dart';
import 'secrets_database.drift.dart';

final class DerivationRepository {
  final SecretsDatabase _database;

  @internal
  const DerivationRepository(this._database);

  Future<Result<List<RecordedDerivation>, SecretFailure>> list(String view) =>
      boundary(() async {
        final rows = await _database
            .customSelect(
              '''
          SELECT d.path, d.parent_fingerprint, d.application, d.status, d.alias
          FROM derivations d
          WHERE EXISTS (
            SELECT 1 FROM view_members m
            WHERE m.view_id = ? AND m.member = 'secret:' || d.parent_fingerprint
          )
          ORDER BY d.parent_fingerprint, d.path
          ''',
              variables: [Variable(view)],
              readsFrom: {_database.derivations, _database.viewMembers},
            )
            .get();
        return List.unmodifiable(
          rows.map(
            (row) => RecordedDerivation(
              path: row.read<String>('path'),
              parentFingerprint: row.read<String>('parent_fingerprint'),
              application: row.read<String>('application'),
              status: row.read<String>('status'),
              alias: row.readNullable<String>('alias'),
            ),
          ),
        );
      }, orElse: FetchSecretFailure.new);

  Future<Result<RecordedDerivation, SecretFailure>> reserveHex({
    required String view,
    required Fingerprint parent,
    required int length,
    String? alias,
  }) {
    if (length < 16 || length > 64) {
      throw ArgumentError('The hex child length must be between 16 and 64');
    }
    const application = bip85.HexApplication();
    return _reserve(
      view: view,
      parent: parent,
      application: 'hex',
      prefix: "${application.number}'/$length'",
      alias: alias,
    );
  }

  Future<Result<RecordedDerivation, SecretFailure>> reserveMnemonic({
    required String view,
    required Fingerprint parent,
    required MnemonicLength length,
    required Language language,
    String? alias,
  }) {
    const application = bip85.MnemonicApplication();
    return _reserve(
      view: view,
      parent: parent,
      application: 'bip39',
      prefix:
          "${application.number}'/${language.toBip85Code()}'/${length.toBip85Code()}'",
      alias: alias,
    );
  }

  Future<Result<RecordedDerivation, SecretFailure>> _reserve({
    required String view,
    required Fingerprint parent,
    required String application,
    required String prefix,
    required String? alias,
  }) => boundary(
    () => _database.transaction(() async {
      // The first write acquires SQLite's writer lock before reading the
      // high-water index, including when another process has opened the store.
      await _database.customStatement(
        'UPDATE access_state SET singleton = singleton WHERE singleton = 1',
      );
      await _requireMembership(view, parent.hex);
      final rows =
          await (_database.select(_database.derivations)..where(
                (d) =>
                    d.parentFingerprint.equals(parent.hex) &
                    d.application.equals(application),
              ))
              .get();
      var index = 0;
      for (final row in rows) {
        final previous = _decode(row).index;
        if (previous == null) throw const _InvalidDerivation();
        if (previous >= index) index = previous + 1;
      }
      if (index >= 0x80000000) throw const _InvalidDerivation();
      final path = "$prefix/$index'";
      final record = DerivationsCompanion.insert(
        parentFingerprint: parent.hex,
        path: path,
        application: application,
        status: 'active',
        alias: Value(alias),
      );
      return _decode(
        await _database.into(_database.derivations).insertReturning(record),
      );
    }),
    orElse: StoreSecretFailure.new,
  );

  Future<Result<void, SecretFailure>> update({
    required String view,
    required String parentFingerprint,
    required String path,
    required DerivationsCompanion change,
  }) => boundary(
    () => _database.transaction(() async {
      await _database.customStatement(
        'UPDATE access_state SET singleton = singleton WHERE singleton = 1',
      );
      await _requireMembership(view, parentFingerprint);
      final count =
          await (_database.update(_database.derivations)..where(
                (d) =>
                    d.parentFingerprint.equals(parentFingerprint) &
                    d.path.equals(path),
              ))
              .write(change);
      if (count != 1) throw const _InvalidDerivation();
    }),
    orElse: StoreSecretFailure.new,
  );

  Future<void> _requireMembership(String view, String parent) async {
    final member =
        await (_database.select(_database.viewMembers)..where(
              (m) => m.viewId.equals(view) & m.member.equals('secret:$parent'),
            ))
            .getSingleOrNull();
    if (member == null) throw const _InvalidDerivation();
  }

  static RecordedDerivation _decode(Derivation row) => RecordedDerivation(
    path: row.path,
    parentFingerprint: row.parentFingerprint,
    application: row.application,
    status: row.status,
    alias: row.alias,
  );
}

final class _InvalidDerivation implements Exception {
  const _InvalidDerivation();
}
