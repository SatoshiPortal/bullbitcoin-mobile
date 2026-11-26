import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';

class FixtureDatabase extends GeneratedDatabase {
  final bool legacy;
  FixtureDatabase(File file, {this.legacy = false})
    : super(
        NativeDatabase(
          file,
          setup: (db) => db.execute('PRAGMA synchronous = FULL'),
        ),
      );
  FixtureDatabase.executor(super.executor, {this.legacy = false});
  @override
  int get schemaVersion => legacy ? 16 : 1;
  @override
  Iterable<TableInfo> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE IF NOT EXISTS sample (id INTEGER PRIMARY KEY, data TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE IF NOT EXISTS legacy_import_receipts (id TEXT PRIMARY KEY NOT NULL)',
      );
    },
  );
}

class FixtureOwner implements LegacyImportParticipant {
  @override
  final String ownerId;
  final File file;
  FixtureOwner(this.ownerId, this.file);
  @override
  Future<bool> hasState() => file.exists();
  @override
  Future<Result<PreparedOwner, LegacyImportFailure>> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  ) async {
    final db = FixtureDatabase(file);
    final handle = admission.track(db.close);
    return Ok(_Prepared(ownerId, db, handle));
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    LifecycleAdmission admission,
  ) async {
    if (!file.existsSync()) return const Ok(OwnerReadiness.pending);
    final db = FixtureDatabase(file);
    final handle = admission.track(db.close);
    try {
      return await _Prepared(ownerId, db, handle).receipt();
    } finally {
      await handle.close();
    }
  }
}

class _Prepared implements PreparedOwner {
  final String id;
  final FixtureDatabase db;
  final LifecycleHandle handle;
  _Prepared(this.id, this.db, this.handle);
  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(LegacySource source) =>
      importLegacyDatabase(
        id: 'split-v1/$id',
        source: source.file,
        sourceSchemaVersion: 16,
        destination: db,
        copyAndVerify: (source) async {
          final rows = source.select('SELECT id, data FROM sample ORDER BY id');
          for (final row in rows) {
            await db.customStatement(
              'INSERT INTO sample VALUES (?, ?)',
              row.values.toList(),
            );
          }
          final target = await db
              .customSelect('SELECT id, data FROM sample ORDER BY id')
              .get();
          return target.length == rows.length &&
              List.generate(
                rows.length,
                (i) =>
                    target[i].data['id'] == rows[i]['id'] &&
                    target[i].data['data'] == rows[i]['data'],
              ).every((x) => x);
        },
      );
  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    await db.transaction(() async {
      if (await hasLegacyImportReceipt(db, 'fresh-v1/$id') case Ok(
        value: true,
      )) {
        return;
      }
      await db.customStatement('INSERT INTO sample VALUES (1, ?)', [
        'initial-$id',
      ]);
      await db.customStatement(
        'INSERT INTO legacy_import_receipts VALUES (?)',
        ['fresh-v1/$id'],
      );
    });
    return const Ok(null);
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() async {
    if (await hasLegacyImportReceipt(db, 'split-v1/$id') case Ok(value: true)) {
      return const Ok(OwnerReadiness.imported);
    }
    if (await hasLegacyImportReceipt(db, 'fresh-v1/$id') case Ok(value: true)) {
      return const Ok(OwnerReadiness.initialized);
    }
    return const Ok(OwnerReadiness.pending);
  }

  @override
  Future<Result<void, LegacyImportFailure>> close() async {
    await handle.close();
    return const Ok(null);
  }
}

class BrokenInspectOwner extends FixtureOwner {
  BrokenInspectOwner(super.ownerId, super.file);
  bool broken = false;
  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    LifecycleAdmission admission,
  ) async =>
      broken ? const Err(LegacyImportUnavailable()) : super.inspect(admission);
}

class FixtureRetirement implements LegacyRetirementParticipant {
  @override
  final String ownerId;
  Result<void, LegacyImportFailure> verdict = const Ok(null);
  final List<String> calls = [];
  final List<OwnerOrigin> origins = [];
  FixtureRetirement(this.ownerId);

  @override
  Future<Result<void, LegacyImportFailure>> verifyRetirable(
    ExclusiveAdmission admission, {
    required OwnerOrigin origin,
    required LegacySource source,
  }) async {
    calls.add('verify');
    origins.add(origin);
    return verdict;
  }
}

StorageCutover fixtureCutover(
  Directory directory, {
  bool later = false,
  Future<void> Function(String)? durableStep,
  List<LegacyRetirementParticipant> retirement = const [],
  List<LegacyImportParticipant>? participants,
}) => StorageCutover(
  directory: Directory('${directory.path}/coordination'),
  legacy: LegacySourceStore(
    source: LegacySource(File('${directory.path}/legacy.sqlite'), 16),
    create: (executor) => FixtureDatabase.executor(executor, legacy: true),
  ),
  expectedOwners: {'pilot', 'later'},
  participants:
      participants ??
      [
        FixtureOwner('pilot', File('${directory.path}/pilot.sqlite')),
        if (later)
          FixtureOwner('later', File('${directory.path}/later.sqlite')),
      ],
  retirementParticipants: retirement,
  requiredRetirementOwners: const {'pilot', 'later'},
  durableStep: durableStep,
);
