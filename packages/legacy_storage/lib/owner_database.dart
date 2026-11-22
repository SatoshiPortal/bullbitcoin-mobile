import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'coordination.dart';
import 'legacy_storage.dart';

/// An owner's checked connection and its registered native lifetime.
final class OwnerDatabase<T extends GeneratedDatabase> {
  final T database;
  final LifecycleHandle handle;

  const OwnerDatabase._(this.database, this.handle);

  /// [openExecutor] runs in the Drift worker. It must capture only
  /// transferable configuration and use the owner's scoped key capability.
  static Future<Result<OwnerDatabase<T>, LegacyImportFailure>>
  open<T extends GeneratedDatabase>({
    required LifecycleAdmission admission,
    required Future<Result<QueryExecutor, LegacyImportFailure>> Function()
    openExecutor,
    required T Function(QueryExecutor) create,
  }) async {
    final settled = Completer<void>();
    T? database;
    DriftIsolate? worker;
    Future<void>? shutdown;
    final confirmation = ReceivePort();
    final confirmed = _receiveAcknowledgement(confirmation);
    final LifecycleHandle handle;
    try {
      handle = admission.track(() async {
        await settled.future;
        try {
          await database?.close();
        } on Exception {
          // The transport may already be gone; the worker must confirm the
          // native close independently below.
          if (worker == null) rethrow;
        }
        if (worker case final isolate?) {
          await (shutdown ??= isolate.shutdownAll());
          await confirmed.timeout(
            const Duration(seconds: 2),
            onTimeout: () =>
                throw const LifecycleException('native_close_unconfirmed'),
          );
        }
        confirmation.close();
      });
    } on LifecycleException {
      confirmation.close();
      return const Err(LegacyImportDeferred());
    }
    final status = ReceivePort();
    final opened = _receiveAcknowledgement(status);
    Result<OwnerDatabase<T>, LegacyImportFailure> result;
    try {
      final isolate = await _spawn(
        openExecutor,
        status.sendPort,
        confirmation.sendPort,
      );
      worker = isolate;
      final selected = create(await isolate.connect());
      database = selected;
      await selected.customSelect('SELECT 1').getSingle();
      result = Ok(OwnerDatabase._(selected, handle));
    } on Exception {
      final failure = worker == null
          ? null
          : await opened.timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
      result = Err(
        failure is LegacyImportFailure
            ? failure
            : const LegacyImportUnavailable(),
      );
    } finally {
      status.close();
      settled.complete();
    }
    if (result case Err()) await handle.close();
    return result;
  }
}

// A port may be closed before it receives a message (for example, when the
// admission is already closed). Closing it must not emit an unhandled error.
Future<Object?> _receiveAcknowledgement(ReceivePort port) {
  final received = Completer<Object?>();
  port.listen((Object? message) {
    if (!received.isCompleted) received.complete(message);
  });
  return received.future;
}

Future<DriftIsolate> _spawn(
  Future<Result<QueryExecutor, LegacyImportFailure>> Function() openExecutor,
  SendPort status,
  SendPort closed,
) => DriftIsolate.spawn(() {
  final nativeClose = NativeCloseAcknowledgement(closed);
  return DatabaseConnection(
    LazyDatabase(() async {
      switch (await openExecutor()) {
        case Ok(:final value):
          status.send(null);
          return value;
        case Err(:final failure):
          nativeClose.openFailedWithoutHandle();
          status.send(failure);
          throw const LifecycleException('owner_open');
      }
    }).interceptWith(nativeClose, sticky: false),
  );
});

/// Copies one explicitly described projection from an immutable snapshot.
/// By default the destination table must match exactly afterwards. If
/// [mergeBy] identifies a primary key, unrelated target rows are allowed
/// but a conflict at an imported key must match in every projected column.
final class OwnerTableCopy {
  final String table;
  final String columns;
  final String orderBy;
  final String? sourceQuery;
  final String? mergeBy;

  const OwnerTableCopy(
    this.table,
    this.columns, {
    required this.orderBy,
    this.sourceQuery,
    this.mergeBy,
  });

  Future<bool> copyAndVerify(
    Database source,
    GeneratedDatabase destination,
  ) async {
    final selection = 'SELECT $columns FROM $table ORDER BY $orderBy';
    final original = source.select(sourceQuery ?? selection);
    final columnNames = columns.split(',');
    if (original.columnNames.length != columnNames.length) return false;
    final placeholders = List.filled(columnNames.length, '?').join(',');
    final key = mergeBy;
    final conflictClause = key == null ? '' : ' ON CONFLICT ($key) DO NOTHING';
    for (final row in original) {
      await destination.customStatement(
        'INSERT INTO $table ($columns) VALUES ($placeholders)$conflictClause',
        row.values.toList(),
      );
    }
    final copied = await destination.customSelect(selection).get();
    if (key != null) {
      final keyPosition = columnNames.indexOf(key);
      if (keyPosition < 0) throw ArgumentError('Missing merge key');
      final byKey = {for (final row in copied) row.data[key]: row.data.values};
      for (final row in original.rows) {
        final target = byKey[row[keyPosition]];
        if (target == null || !sameSqliteValues(row, target.toList())) {
          return false;
        }
      }
      return true;
    }
    if (copied.length != original.length) return false;
    for (var index = 0; index < original.length; index++) {
      final before = original[index].values.toList();
      final after = copied[index].data.values.toList();
      if (!sameSqliteValues(before, after)) return false;
    }
    return true;
  }
}

bool sameSqliteValues(List<Object?> before, List<Object?> after) {
  if (before.length != after.length) return false;
  for (var column = 0; column < before.length; column++) {
    if (!_sameValue(before[column], after[column])) return false;
  }
  return true;
}

/// Preserves the high-water marks of owner-declared AUTOINCREMENT tables,
/// including when the source has deleted its highest-numbered row.
Future<bool> copySequence(
  Database source,
  GeneratedDatabase destination,
  String table,
) async {
  final saved = source.select(
    'SELECT seq FROM sqlite_sequence WHERE name = ?',
    [table],
  );
  if (saved.length > 1) return false;
  if (saved.isEmpty) return true;
  final sequence = saved.single['seq'];
  if (sequence is! int) return false;
  final current = await destination
      .customSelect(
        'SELECT seq FROM sqlite_sequence WHERE name = ?',
        variables: [Variable(table)],
      )
      .getSingleOrNull();
  if (current != null && current.read<int>('seq') > sequence) return false;
  if (current == null) {
    await destination.customStatement(
      'INSERT INTO sqlite_sequence (name, seq) VALUES (?, ?)',
      [table, sequence],
    );
  } else {
    await destination.customStatement(
      'UPDATE sqlite_sequence SET seq = ? WHERE name = ?',
      [sequence, table],
    );
  }
  final copied = await destination
      .customSelect(
        'SELECT seq FROM sqlite_sequence WHERE name = ?',
        variables: [Variable(table)],
      )
      .getSingle();
  return copied.read<int>('seq') == sequence;
}

/// Reads a standalone legacy file without running its original Drift opener.
/// The caller must already hold exclusive admission. A missing main file with
/// surviving sidecars or quarantine entries is not an empty source.
Future<bool> readStandaloneSource(
  File file,
  Future<bool> Function(Database? source) read,
) async {
  final present = _familyMemberPresent(file);
  if (_familyMemberPresent(File('${file.path}.retire-pending'))) return false;
  if (!present) {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      if (_familyMemberPresent(File('${file.path}$suffix'))) return false;
    }
  }
  if (file.parent.existsSync()) {
    final basename = file.uri.pathSegments.last;
    if (file.parent.listSync(followLinks: false).any((entry) {
      final name = entry.uri.pathSegments.last;
      return [
        basename,
        '$basename-wal',
        '$basename-shm',
        '$basename-journal',
      ].any((member) => name.startsWith('$member.unreadable-'));
    })) {
      return false;
    }
  }
  if (!present) return read(null);

  final source = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    source.execute('BEGIN');
    return await read(source);
  } finally {
    source.close();
  }
}

bool _familyMemberPresent(File file) {
  try {
    file.lengthSync();
    return true;
  } on PathNotFoundException {
    return false;
  }
}

/// Records the result of inspecting the standalone file in the same
/// transaction as the root readiness receipt, even on a rootless install.
Future<bool> importStandaloneSource(
  File file,
  GeneratedDatabase destination,
  String owner,
  Future<bool> Function(Database? source) copyAndVerify,
) => readStandaloneSource(file, (source) async {
  if (!await copyAndVerify(source)) return false;
  await destination.customStatement(
    'INSERT INTO legacy_import_receipts (id) VALUES (?)',
    [_standaloneReceipt(owner, present: source != null)],
  );
  return true;
});

String _standaloneReceipt(String owner, {required bool present}) =>
    'standalone-v1/$owner/${present ? 'imported' : 'absent'}';

bool _sameValue(Object? before, Object? after) {
  if (before is Uint8List && after is Uint8List) {
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      if (before[i] != after[i]) return false;
    }
    return true;
  }
  return before == after && before.runtimeType == after.runtimeType;
}

/// The two committed states are mutually exclusive. Missing receipts are
/// pending, never proof of a fresh installation.
Future<Result<OwnerReadiness, LegacyImportFailure>> ownerReadiness(
  GeneratedDatabase database,
  String owner, {
  bool standalone = false,
}) async {
  final imported = await hasLegacyImportReceipt(database, 'split-v1/$owner');
  final fresh = await hasLegacyImportReceipt(database, 'fresh-v1/$owner');
  final Result<OwnerReadiness, LegacyImportFailure> readiness = switch ((
    imported,
    fresh,
  )) {
    (Err(:final failure), _) || (_, Err(:final failure)) => Err(failure),
    (Ok(value: true), Ok(value: true)) => const Err(
      LegacyImportVerificationFailed(),
    ),
    (Ok(value: true), Ok(value: false)) => const Ok(OwnerReadiness.imported),
    (Ok(value: false), Ok(value: true)) => const Ok(OwnerReadiness.initialized),
    (Ok(value: false), Ok(value: false)) => const Ok(OwnerReadiness.pending),
  };
  if (!standalone ||
      readiness is! Ok<OwnerReadiness, LegacyImportFailure> ||
      readiness.value == OwnerReadiness.pending) {
    return readiness;
  }
  final present = await hasLegacyImportReceipt(
    database,
    _standaloneReceipt(owner, present: true),
  );
  final absent = await hasLegacyImportReceipt(
    database,
    _standaloneReceipt(owner, present: false),
  );
  return switch ((present, absent)) {
    (Err(:final failure), _) || (_, Err(:final failure)) => Err(failure),
    (Ok(value: true), Ok(value: false)) ||
    (Ok(value: false), Ok(value: true)) => readiness,
    _ => const Err(LegacyImportVerificationFailed()),
  };
}

/// A projected owner. Optional source reconciliation and fresh seeding run
/// in the same destination transaction as the readiness receipt.
final class ProjectedOwner<T extends GeneratedDatabase>
    implements LegacyImportParticipant {
  @override
  final String ownerId;
  final File file;
  final List<OwnerTableCopy> tables;
  final Future<Result<OwnerDatabase<T>, LegacyImportFailure>> Function(
    LifecycleAdmission admission, {
    required bool existing,
  })
  open;
  final Future<bool> Function(Database? root, T destination)? complete;
  final bool standalone;

  const ProjectedOwner({
    required this.ownerId,
    required this.file,
    required this.tables,
    required this.open,
    this.complete,
    this.standalone = false,
  });

  @override
  Future<bool> hasState() async => [
    '',
    '-wal',
    '-shm',
    '-journal',
    '.retire-pending',
  ].any((suffix) => _familyMemberPresent(File('${file.path}$suffix')));

  @override
  Future<Result<PreparedOwner, LegacyImportFailure>> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  ) async {
    final opened = await open(admission, existing: false);
    return opened.map((store) => _PreparedProjection(this, store));
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  ) async {
    final opened = await open(admission, existing: true);
    if (opened case Err(:final failure)) return Err(failure);
    final store = (opened as Ok<OwnerDatabase<T>, LegacyImportFailure>).value;
    try {
      return await ownerReadiness(
        store.database,
        ownerId,
        standalone: standalone,
      );
    } finally {
      await store.handle.close();
    }
  }
}

final class _PreparedProjection<T extends GeneratedDatabase>
    implements PreparedOwner {
  final ProjectedOwner<T> owner;
  final OwnerDatabase<T> store;

  const _PreparedProjection(this.owner, this.store);

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(LegacySource source) =>
      importLegacyDatabase(
        id: 'split-v1/${owner.ownerId}',
        source: source.file,
        sourceSchemaVersion: source.schemaVersion,
        destination: store.database,
        copyAndVerify: (source) async {
          final fresh = await hasLegacyImportReceipt(
            store.database,
            'fresh-v1/${owner.ownerId}',
          );
          if (fresh is! Ok<bool, LegacyImportFailure> || fresh.value) {
            return false;
          }
          if (!await _empty()) return false;
          for (final table in owner.tables) {
            if (!await table.copyAndVerify(source, store.database)) {
              return false;
            }
          }
          return await owner.complete?.call(source, store.database) ?? true;
        },
      );

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    try {
      return await store.database.transaction(() async {
        final readiness = await receipt();
        if (readiness case Ok(value: OwnerReadiness.initialized)) {
          return const Ok(null);
        }
        if (readiness is! Ok<OwnerReadiness, LegacyImportFailure> ||
            readiness.value != OwnerReadiness.pending) {
          return const Err(LegacyImportVerificationFailed());
        }
        if (!await _empty()) return const Err(LegacyImportVerificationFailed());
        await store.database.customStatement('''
          CREATE TABLE IF NOT EXISTS legacy_import_receipts (
            id TEXT PRIMARY KEY NOT NULL
          )
        ''');
        if (!(await owner.complete?.call(null, store.database) ?? true)) {
          // Roll back anything the reconciliation wrote before failing.
          throw const _OwnerVerificationRejected();
        }
        await store.database.customStatement(
          'INSERT INTO legacy_import_receipts (id) VALUES (?)',
          ['fresh-v1/${owner.ownerId}'],
        );
        return const Ok(null);
      });
    } on _OwnerVerificationRejected {
      return const Err(LegacyImportVerificationFailed());
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    } on FileSystemException {
      return const Err(LegacyImportUnavailable());
    }
  }

  Future<bool> _empty() async {
    final tables = {
      for (final table in store.database.allTables) table.actualTableName,
      for (final table in owner.tables) table.table,
    }..remove('legacy_import_receipts');
    for (final table in tables) {
      final existing = await store.database
          .customSelect('SELECT 1 FROM $table LIMIT 1')
          .get();
      if (existing.isNotEmpty) return false;
    }
    return true;
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      ownerReadiness(
        store.database,
        owner.ownerId,
        standalone: owner.standalone,
      );

  @override
  Future<Result<void, LegacyImportFailure>> close() async {
    try {
      await store.handle.close();
      return const Ok(null);
    } on Exception {
      return const Err(LegacyImportUnavailable());
    }
  }
}

final class _OwnerVerificationRejected implements Exception {
  const _OwnerVerificationRejected();
}
