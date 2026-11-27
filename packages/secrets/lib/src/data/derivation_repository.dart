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

  /// Merges archived records for [parent] under the allocator's writer lock.
  ///
  /// Every record is validated before anything is written: a malformed path,
  /// an application that does not match its path, a duplicate, a record of
  /// another parent or a conflict with an existing row refuses the whole
  /// archive. Missing rows are inserted as they are, so gaps stay gaps. An
  /// existing row never loses information: a revoked or inactive child stays
  /// so, and a local alias is kept. The next allocation index is read from
  /// the table, so a merge can only raise it.
  Future<Result<DerivationMergeReport, SecretFailure>> merge({
    required String view,
    required Fingerprint parent,
    required List<RecordedDerivation> records,
  }) async {
    final seen = <String>{};
    for (final record in records) {
      if (record.parentFingerprint != parent.hex ||
          !isCanonicalDerivation(record.application, record.path) ||
          !_statuses.containsKey(record.status) ||
          !seen.add(record.path)) {
        return const Err(incompatibleBip85ArchiveFailure);
      }
    }
    final merged = await boundary<DerivationMergeReport?>(() async {
      try {
        return await _database.transaction(() async {
          await _database.customStatement(
            'UPDATE access_state SET singleton = singleton WHERE singleton = 1',
          );
          await _requireMembership(view, parent.hex);
          final existing = {
            for (final row in await (_database.select(
              _database.derivations,
            )..where((d) => d.parentFingerprint.equals(parent.hex))).get())
              row.path: row,
          };
          final inserts = <DerivationsCompanion>[];
          final updates = <(String, DerivationsCompanion)>[];
          var unchanged = 0;
          for (final record in records) {
            final local = existing[record.path];
            if (local == null) {
              inserts.add(
                DerivationsCompanion.insert(
                  parentFingerprint: parent.hex,
                  path: record.path,
                  application: record.application,
                  status: record.status,
                  alias: Value(record.alias),
                ),
              );
              continue;
            }
            final archived = _statuses[record.status];
            final stored = _statuses[local.status];
            if (local.application != record.application ||
                archived == null ||
                stored == null) {
              throw const _IncompatibleArchive();
            }
            final status = archived > stored ? record.status : local.status;
            final alias = local.alias ?? record.alias;
            if (status == local.status && alias == local.alias) {
              unchanged++;
            } else {
              updates.add((
                record.path,
                DerivationsCompanion(
                  status: Value(status),
                  alias: Value(alias),
                ),
              ));
            }
          }
          for (final insert in inserts) {
            await _database.into(_database.derivations).insert(insert);
          }
          for (final (path, change) in updates) {
            await (_database.update(_database.derivations)..where(
                  (d) =>
                      d.parentFingerprint.equals(parent.hex) &
                      d.path.equals(path),
                ))
                .write(change);
          }
          return DerivationMergeReport(
            added: inserts.length,
            updated: updates.length,
            unchanged: unchanged,
          );
        });
      } on _IncompatibleArchive {
        return null;
      }
    }, orElse: StoreSecretFailure.new);
    return switch (merged) {
      Ok(value: final report?) => Ok(report),
      Ok() => const Err(incompatibleBip85ArchiveFailure),
      Err(:final failure) => Err(failure),
    };
  }

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

final class _IncompatibleArchive implements Exception {
  const _IncompatibleArchive();
}

/// Restrictiveness order: a merge never moves a child toward `active`.
const _statuses = {'active': 0, 'inactive': 1, 'revoked': 2};

/// The only paths this app allocates: `128169'/<16..64>'/<i>'` (hex) and
/// `39'/<language 0..9>'/<12|15|18|21|24>'/<i>'` (bip39), hardened and
/// canonical, with an index below 2^31 and no leading zeros.
bool isCanonicalDerivation(String application, String path) {
  final segments = path.split('/');
  final numbers = <int>[];
  for (final segment in segments) {
    if (!RegExp(r"^(0|[1-9][0-9]{0,9})'$").hasMatch(segment)) return false;
    final value = int.parse(segment.substring(0, segment.length - 1));
    if (value >= 0x80000000) return false;
    numbers.add(value);
  }
  return switch (application) {
    'hex' =>
      numbers.length == 3 &&
          numbers[0] == 128169 &&
          numbers[1] >= 16 &&
          numbers[1] <= 64,
    'bip39' =>
      numbers.length == 4 &&
          numbers[0] == 39 &&
          numbers[1] <= 9 &&
          const {12, 15, 18, 21, 24}.contains(numbers[2]),
    _ => false,
  };
}

/// What a derivation merge changed.
final class DerivationMergeReport {
  final int added;
  final int updated;
  final int unchanged;

  const DerivationMergeReport({
    required this.added,
    required this.updated,
    required this.unchanged,
  });
}
