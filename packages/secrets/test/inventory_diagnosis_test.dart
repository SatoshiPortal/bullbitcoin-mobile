import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/access_repository.dart';
import 'package:secrets/src/data/backup_guard.dart';
import 'package:secrets/src/data/database_key_repository.dart';
import 'package:secrets/src/data/encrypted_database.dart'
    show openEncryptedDatabase;
import 'package:secrets/src/data/inventory_import.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/src/data/secrets_database.dart';
import 'package:secrets/src/domain/database_open_failure.dart';
import 'package:secrets/src/public/secrets_inventory.dart'
    show SecretsInventory, inventoryReadinessFailure;
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

/// The wallet storage diagnosis, driven through the coordinator that decides
/// what an unreadable admitted owner means.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late Directory databases;
  late File file;

  StorageCutover cutover() => StorageCutover(
    directory: Directory('${directory.path}/coordination'),
    legacy: LegacySourceStore(
      source: LegacySource(File('${directory.path}/legacy.sqlite'), 16),
      create: (executor) => _LegacyFixture(executor),
    ),
    expectedOwners: {'secrets'},
    participants: [SecretsImport(file: file)],
    destinationFamilies: [file],
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-diagnosis-');
    databases = Directory('${directory.path}/databases')..createSync();
    file = File('${databases.path}/secrets.sqlite');
    FakeSecureStoragePlatform().install();
    final first = await cutover().prepare();
    expect(first, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
    await (first as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
    expect(file.existsSync(), isTrue);
  });

  tearDown(() async {
    await Process.run('chmod', ['700', databases.path]);
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  Future<Result<RuntimeAdmission, LegacyImportFailure>> reopen({
    bool shared = false,
  }) async {
    final result = shared
        ? await cutover().admit(timeout: Duration.zero)
        : await cutover().prepare(timeout: Duration.zero);
    if (result case Ok(:final value)) await value.close();
    return result;
  }

  Matcher ownerFailure(LegacyOwnerFailureCause cause) =>
      isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<LegacyOwnerFailure>()
            .having((f) => f.ownerId, 'ownerId', 'secrets')
            .having((f) => f.cause, 'cause', cause),
      );

  Matcher plainUnavailable() =>
      isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<LegacyImportUnavailable>(),
      );

  test('a readable inventory is admitted again', () async {
    expect(await reopen(), isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
  });

  test('a missing file is lost after admission and is not recreated', () async {
    await file.delete();
    expect(
      await reopen(),
      ownerFailure(LegacyOwnerFailureCause.missingAfterAdmission),
    );
    expect(file.existsSync(), isFalse);
  });

  test('a sidecar without its main file is not a present inventory', () async {
    await file.delete();
    final sidecar = await File('${file.path}-wal').writeAsBytes([1, 2, 3]);
    expect(
      await reopen(),
      ownerFailure(LegacyOwnerFailureCause.missingAfterAdmission),
    );
    expect(
      await reopen(shared: true),
      ownerFailure(LegacyOwnerFailureCause.missingAfterAdmission),
    );
    expect(file.existsSync(), isFalse);
    expect(await sidecar.readAsBytes(), [1, 2, 3]);
  });

  test(
    'an empty main file is unreadable, never an old schema to retry',
    () async {
      await file.writeAsBytes(const []);
      expect(await reopen(), ownerFailure(LegacyOwnerFailureCause.unreadable));
      expect(
        await reopen(shared: true),
        ownerFailure(LegacyOwnerFailureCause.unreadable),
      );
      expect(await file.length(), 0);
    },
  );

  test('a refused access is an I/O failure, not a lost inventory', () async {
    final original = await file.readAsBytes();
    await Process.run('chmod', ['000', databases.path]);
    if (Directory(databases.path).statSync().mode & 0x1ff != 0) {
      markTestSkipped('permissions are not enforced for this user');
      return;
    }
    expect(await reopen(), plainUnavailable());
    expect(await reopen(shared: true), plainUnavailable());
    await Process.run('chmod', ['700', databases.path]);
    expect(await file.readAsBytes(), original);
    expect(await reopen(), isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
  });

  test(
    'contention is kept, and admission succeeds once it is released',
    () async {
      final gate = NativeFileGate(
        File('${directory.path}/coordination/lifecycle.lock'),
      );
      final holder = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      final opened = await InventoryStore.open(file, holder, existing: true);
      final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
      await store.database.customStatement('PRAGMA locking_mode = EXCLUSIVE');
      await store.database.customSelect('SELECT 1 FROM access_state').get();
      await store.database.customStatement('BEGIN EXCLUSIVE');

      final contended = await cutover().admit(timeout: Duration.zero);
      expect(contended, ownerFailure(LegacyOwnerFailureCause.contention));

      await store.database.customStatement('COMMIT');
      await store.close();
      await holder.close();
      final released = await cutover().admit(timeout: Duration.zero);
      expect(released, isA<Ok<RuntimeAdmission, LegacyImportFailure>>());
      await (released as Ok<RuntimeAdmission, LegacyImportFailure>).value
          .close();
    },
  );

  test(
    'a receipt this build does not know is not an unreadable file',
    () async {
      final gate = NativeFileGate(
        File('${directory.path}/coordination/lifecycle.lock'),
      );
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      try {
        final opened = await InventoryStore.open(
          file,
          admission,
          existing: true,
        );
        final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
        await store.database.customStatement(
          "UPDATE access_state SET import_receipt = 'recovered-v9/secrets'",
        );
        await store.close();
        final result = await SecretsInventory.open(
          file: file,
          admission: admission,
          authority: unlockedSessionAuthority(),
        );
        expect(
          result,
          isA<Err<SecretsInventory, DatabaseOpenFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<DatabaseFileUnavailable>().having(
              (f) => f.reason,
              'reason',
              isNot(DatabaseFileProblem.unreadable),
            ),
          ),
        );
      } finally {
        await admission.close();
      }
    },
  );

  test('every readiness failure keeps its own cause', () {
    DatabaseOpenFailure map(LegacyImportFailure f) =>
        inventoryReadinessFailure(f);
    expect(
      map(
        const LegacyOwnerFailure('secrets', LegacyOwnerFailureCause.contention),
      ),
      isA<DatabaseFileUnavailable>().having(
        (f) => f.reason,
        'reason',
        DatabaseFileProblem.contended,
      ),
    );
    expect(
      map(
        const LegacyOwnerFailure('secrets', LegacyOwnerFailureCause.unreadable),
      ),
      isA<DatabaseFileUnavailable>().having(
        (f) => f.reason,
        'reason',
        DatabaseFileProblem.unreadable,
      ),
    );
    expect(
      map(const LegacyOwnerFailure('secrets', LegacyOwnerFailureCause.keyLost)),
      isA<DatabaseKeyUnavailable>().having(
        (f) => f.reason,
        'reason',
        DatabaseKeyProblem.missing,
      ),
    );
    expect(
      map(const LegacyImportDeferred()),
      isA<DatabaseKeyUnavailable>().having(
        (f) => f.reason,
        'reason',
        DatabaseKeyProblem.locked,
      ),
    );
    expect(
      map(const LegacyImportUnavailable()),
      isA<DatabaseFileUnavailable>().having(
        (f) => f.reason,
        'reason',
        DatabaseFileProblem.inaccessible,
      ),
    );
  });

  test(
    'a first query that fails as corrupt is unreadable and leaves the file',
    () async {
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(8192));
      // Keep page 1, which holds sqlite_master, and damage every other page.
      final damaged = List<int>.of(bytes);
      for (var i = 4096; i < damaged.length; i++) {
        damaged[i] = (i * 31 + 7) & 0xff;
      }
      await file.writeAsBytes(damaged);

      // The key is accepted and sqlite_master reads: only access_state fails.
      final executor = await openEncryptedDatabase(
        DatabaseKeyRepository(),
        module: inventoryModule,
        name: 'main',
        file: file,
        existingSchemaVersion: 1,
      );
      expect(executor, isA<Ok<QueryExecutor, DatabaseOpenFailure>>());
      await (executor as Ok<QueryExecutor, DatabaseOpenFailure>).value.close();

      final gate = NativeFileGate(
        File('${directory.path}/coordination/lifecycle.lock'),
      );
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      try {
        expect(
          await InventoryStore.open(file, admission, existing: true),
          isA<Err<InventoryStore, DatabaseOpenFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<DatabaseFileUnavailable>().having(
              (f) => f.reason,
              'reason',
              DatabaseFileProblem.unreadable,
            ),
          ),
        );
        expect(
          await SecretsImport(file: file).inspect(admission),
          isA<Err<OwnerReadiness, LegacyImportFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<LegacyOwnerFailure>().having(
              (f) => f.cause,
              'cause',
              LegacyOwnerFailureCause.unreadable,
            ),
          ),
        );
      } finally {
        await admission.close();
      }
      expect(await file.readAsBytes(), damaged);
      expect(File('${file.path}-wal').existsSync(), isFalse);
    },
  );

  group('the second opening keeps the cause of each failed read', () {
    final faults = {
      'busy': (SqlError.SQLITE_BUSY, DatabaseFileProblem.contended),
      'corrupt': (SqlError.SQLITE_CORRUPT, DatabaseFileProblem.unreadable),
      'an I/O error': (SqlError.SQLITE_IOERR, DatabaseFileProblem.inaccessible),
    };

    Future<(SecretsDatabase, _Fault)> faulty() async {
      final fault = _Fault();
      final database = SecretsDatabase(
        NativeDatabase.memory().interceptWith(fault),
      );
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();
      return (database, fault);
    }

    for (final MapEntry(:key, :value) in faults.entries) {
      final (code, expected) = value;

      test('reconciling access after $key', () async {
        final (database, fault) = await faulty();
        fault.code = code;
        final result = await reconcileInventoryAccess(database);
        final failure = (result as Err<void, LegacyImportFailure>).failure;
        expect(
          inventoryReadinessFailure(failure),
          isA<DatabaseFileUnavailable>().having(
            (f) => f.reason,
            'reason',
            expected,
          ),
        );
      });

      test('reading the protection after $key', () async {
        final (database, fault) = await faulty();
        fault.code = code;
        final result = await AccessRepository(
          database,
          BackupGuard(null, database),
        ).protectionAtOpen();
        expect(
          result,
          isA<Err<bool, DatabaseOpenFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<DatabaseFileUnavailable>().having(
              (f) => f.reason,
              'reason',
              expected,
            ),
          ),
        );
      });
    }
  });

  group('the second opening of an admitted inventory', () {
    Future<Result<SecretsInventory, DatabaseOpenFailure>> second() async {
      final gate = NativeFileGate(
        File('${directory.path}/coordination/lifecycle.lock'),
      );
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      try {
        return await SecretsInventory.open(
          file: file,
          admission: admission,
          authority: unlockedSessionAuthority(),
        );
      } finally {
        await admission.close();
      }
    }

    Matcher problem(DatabaseFileProblem reason) =>
        isA<Err<SecretsInventory, DatabaseOpenFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<DatabaseFileUnavailable>().having(
            (f) => f.reason,
            'reason',
            reason,
          ),
        );

    test('a missing file is missing, and is not recreated', () async {
      await file.delete();
      expect(await second(), problem(DatabaseFileProblem.missing));
      expect(file.existsSync(), isFalse);
    });

    test('a sidecar alone is missing, and nothing is recreated', () async {
      await file.delete();
      final sidecar = await File('${file.path}-wal').writeAsBytes([1, 2, 3]);
      expect(await second(), problem(DatabaseFileProblem.missing));
      expect(file.existsSync(), isFalse);
      expect(await sidecar.readAsBytes(), [1, 2, 3]);
    });

    test(
      'an empty file without a WAL is unreadable, not to be waited out',
      () async {
        await file.writeAsBytes(const []);
        expect(await second(), problem(DatabaseFileProblem.unreadable));
        expect(await file.length(), 0);
        expect(File('${file.path}-wal').existsSync(), isFalse);
      },
    );

    test('a file the engine cannot open is an access error', () async {
      final original = await file.readAsBytes();
      await Process.run('chmod', ['000', file.path]);
      addTearDown(() => Process.run('chmod', ['600', file.path]));
      if (file.statSync().mode & 0x1ff != 0) {
        markTestSkipped('permissions are not enforced for this user');
        return;
      }
      expect(await second(), problem(DatabaseFileProblem.inaccessible));
      await Process.run('chmod', ['600', file.path]);
      expect(await file.readAsBytes(), original);
    });

    test('a locked file is contention', () async {
      final gate = NativeFileGate(
        File('${directory.path}/coordination/lifecycle.lock'),
      );
      final holder = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      final opened = await InventoryStore.open(file, holder, existing: true);
      final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
      await store.database.customStatement('PRAGMA locking_mode = EXCLUSIVE');
      await store.database.customSelect('SELECT 1 FROM access_state').get();
      await store.database.customStatement('BEGIN EXCLUSIVE');
      try {
        expect(await second(), problem(DatabaseFileProblem.contended));
      } finally {
        await store.database.customStatement('COMMIT');
        await store.close();
        await holder.close();
      }
    });

    test(
      'damage to the default view page is unreadable and leaves the file',
      () async {
        final gate = NativeFileGate(
          File('${directory.path}/coordination/lifecycle.lock'),
        );
        final admission = await gate.acquire(
          exclusive: false,
          timeout: Duration.zero,
        ) as RuntimeAdmission;
        late int page;
        try {
          final opened = await InventoryStore.open(
            file,
            admission,
            existing: true,
          );
          final store =
              (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
          final root = await store.database
              .customSelect(
                "SELECT rootpage FROM sqlite_master WHERE name = 'views'",
              )
              .getSingle();
          page = root.read<int>('rootpage');
          await store.close();
        } finally {
          await admission.close();
        }
        final bytes = await file.readAsBytes();
        final damaged = List<int>.of(bytes);
        for (var i = (page - 1) * 4096; i < page * 4096; i++) {
          damaged[i] = (i * 31 + 7) & 0xff;
        }
        await file.writeAsBytes(damaged);
        final r = await second();
        expect(r, problem(DatabaseFileProblem.unreadable));
        expect(await file.readAsBytes(), damaged);
      },
    );
  });

  test('contention while reading the receipt is kept', () async {
    final database = SecretsDatabase(
      NativeDatabase.memory().interceptWith(_BusyOnSelect()),
    );
    addTearDown(database.close);
    expect(
      await readInventoryReadiness(database, admitted: true),
      isA<Err<OwnerReadiness, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<LegacyOwnerFailure>().having(
          (f) => f.cause,
          'cause',
          LegacyOwnerFailureCause.contention,
        ),
      ),
    );
    expect(
      await readInventoryReadiness(database),
      isA<Err<OwnerReadiness, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure before admission',
        isA<LegacyImportUnavailable>(),
      ),
    );
  });
}

final class _BusyOnSelect extends QueryInterceptor {
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => throw SqliteException(
    extendedResultCode: SqlError.SQLITE_BUSY,
    message: 'database is locked',
  );
}

final class _LegacyFixture extends GeneratedDatabase {
  _LegacyFixture(super.executor);

  @override
  int get schemaVersion => 16;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement(
      'CREATE TABLE IF NOT EXISTS legacy_import_receipts '
      '(id TEXT PRIMARY KEY NOT NULL)',
    ),
  );
}

/// Fails every statement with an engine error once a code is set. The fault
/// is raised before the statement is delegated, so it never reaches the engine.
final class _Fault extends QueryInterceptor {
  int? code;

  void _throwIfFaulty() {
    if (code case final code?) {
      throw SqliteException(extendedResultCode: code, message: 'injected');
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _throwIfFaulty();
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _throwIfFaulty();
    return super.runCustom(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _throwIfFaulty();
    return super.runUpdate(executor, statement, args);
  }
}
