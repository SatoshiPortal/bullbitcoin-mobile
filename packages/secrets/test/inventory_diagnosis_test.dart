import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/inventory_import.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/src/data/secrets_database.dart';
import 'package:secrets/src/domain/database_open_failure.dart';
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
