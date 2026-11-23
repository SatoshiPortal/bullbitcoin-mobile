import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File root;
  late File encrypted;
  late NativeFileGate gate;
  late ProjectedOwner<_OwnerFixture> owner;
  const when = '2026-11-22 13:14:12.345678Z';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('projected-owner-');
    root = File('${directory.path}/root.sqlite');
    encrypted = File('${directory.path}/destination.sqlite');
    gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
    final source = sqlite3.open(root.path);
    try {
      source.userVersion = 16;
      source.execute(_createRows);
      source.execute('INSERT INTO dismissed_announcements VALUES (?, ?, ?)', [
        'olderAppOnly',
        when,
        Uint8List.fromList([0, 255, 37]),
      ]);
    } finally {
      source.close();
    }
    owner = ProjectedOwner(
      ownerId: 'announcements',
      file: encrypted,
      tables: const [
        OwnerTableCopy(
          'dismissed_announcements',
          'announcement_id,dismissed_at,payload',
          orderBy: 'announcement_id',
        ),
      ],
      open: (admission, {required existing}) => OwnerDatabase.open(
        admission: admission,
        openExecutor: _opener(encrypted.path),
        create: _OwnerFixture.new,
      ),
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('opening on a closed admission returns a typed failure', () async {
    final admission = await gate.acquire(
      exclusive: false,
      timeout: const Duration(seconds: 1),
    );
    await admission.close();
    final opened = await OwnerDatabase.open(
      admission: admission,
      openExecutor: _opener(encrypted.path),
      create: _OwnerFixture.new,
    );
    expect(
      opened,
      isA<Err<OwnerDatabase<_OwnerFixture>, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<LegacyImportDeferred>(),
      ),
    );
    expect(encrypted.existsSync(), isFalse);
  });

  test(
    'keeps raw timestamps, unknown IDs and blobs across worker reopen',
    () async {
      final lease = await gate.acquire(
        exclusive: true,
        timeout: const Duration(seconds: 1),
      ) as ExclusiveAdmission;
      try {
        final opened = await owner.prepare(lease, OwnerOrigin.legacy);
        final prepared =
            (opened as Ok<PreparedOwner, LegacyImportFailure>).value;
        expect(await prepared.importLegacy(LegacySource(root, 16)), isA<Ok>());
        expect(await prepared.close(), isA<Ok>());
      } finally {
        await lease.close();
      }
      final shared = await gate.acquire(
        exclusive: false,
        timeout: const Duration(seconds: 1),
      ) as RuntimeAdmission;
      try {
        expect(
          await owner.inspect(shared),
          isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
            (result) => result.value,
            'readiness',
            OwnerReadiness.imported,
          ),
        );
        final store = sqlite3.open(encrypted.path, mode: OpenMode.readOnly);
        try {
          final row = store
              .select('SELECT * FROM dismissed_announcements')
              .single;
          expect(row['announcement_id'], 'olderAppOnly');
          expect(row['dismissed_at'], when);
          expect(row['payload'], orderedEquals([0, 255, 37]));
        } finally {
          store.close();
        }
      } finally {
        await shared.close();
      }
    },
  );

  test(
    'source reconciliation failure rolls back projection and receipt',
    () async {
      final rejected = ProjectedOwner(
        ownerId: owner.ownerId,
        file: encrypted,
        tables: owner.tables,
        open: owner.open,
        complete: (_, _) async => false,
      );
      final lease = await gate.acquire(
        exclusive: true,
        timeout: const Duration(seconds: 1),
      ) as ExclusiveAdmission;
      try {
        final opened = await rejected.prepare(lease, OwnerOrigin.legacy);
        final prepared =
            (opened as Ok<PreparedOwner, LegacyImportFailure>).value;
        expect(
          await prepared.importLegacy(LegacySource(root, 16)),
          isA<Err<void, LegacyImportFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<LegacyImportVerificationFailed>(),
          ),
        );
        expect(await prepared.close(), isA<Ok>());
      } finally {
        await lease.close();
      }
      final store = sqlite3.open(encrypted.path, mode: OpenMode.readOnly);
      try {
        expect(store.select('SELECT * FROM dismissed_announcements'), isEmpty);
        expect(store.select('SELECT * FROM legacy_import_receipts'), isEmpty);
      } finally {
        store.close();
      }
    },
  );

  test('an orphaned standalone WAL is not an empty source', () async {
    final standalone = File('${directory.path}/standalone.sqlite');
    File('${standalone.path}-wal').createSync();
    expect(
      await readStandaloneSource(
        standalone,
        (_) async => throw StateError('inconsistent source established'),
      ),
      isFalse,
    );
  });

  test('quarantine without a replacement is not an empty source', () async {
    final standalone = File('${directory.path}/payjoin.sqlite');
    final quarantine = File('${standalone.path}.unreadable-1');
    await quarantine.writeAsBytes([0, 1, 255]);
    final reasons = <String>[];
    expect(
      await readStandaloneSource(
        standalone,
        (_) async => fail('orphaned quarantine must not be opened'),
        onRejected: reasons.add,
      ),
      isFalse,
    );
    expect(reasons, ['standalone_orphaned_quarantine']);
    expect(await quarantine.readAsBytes(), [0, 1, 255]);
  });
}

const _createRows = '''
  CREATE TABLE dismissed_announcements (
    announcement_id TEXT PRIMARY KEY NOT NULL,
    dismissed_at TEXT NOT NULL,
    payload BLOB NOT NULL
  )
''';

final class _OwnerFixture extends GeneratedDatabase {
  _OwnerFixture(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(_createRows);
      await customStatement(
        'CREATE TABLE legacy_import_receipts (id TEXT PRIMARY KEY NOT NULL)',
      );
    },
  );
}

Future<Result<QueryExecutor, LegacyImportFailure>> Function() _opener(
  String path,
) =>
    () async => Ok(NativeDatabase(File(path)));
