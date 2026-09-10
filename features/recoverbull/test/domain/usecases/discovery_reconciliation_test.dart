import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_drive_discovery_port.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/usecases/discover_drive_backups_usecase.dart';
import 'package:bull_recoverbull/src/data/google_drive_backup_discovery_adapter.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  Future<(RecoverBullDatabase, RecoverBullAttemptMonitoringStore)>
  build() async {
    final db = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await db.ensureState();
    return (db, RecoverBullAttemptMonitoringStore(db));
  }

  test(
    'discovers unique and duplicate vaults, and reports invalid files',
    () async {
      expect(EncryptedVault.isValid(_valid('01')), isTrue);
      final (db, store) = await build();
      final drive = _FakeDrive({
        'a': _valid('01'),
        'b': _valid('02'),
        'duplicate': _valid('01'),
        'invalid': '{"not":"a vault"}',
      });
      final log = _CaptureLog();
      final result = await DiscoverDriveBackupsUsecase(
        drive: drive,
        store: store,
        log: log,
      ).execute();
      expect(result.status, DriveDiscoveryStatus.partial);
      expect(result.listed, 4);
      expect(result.invalid, 1);
      expect(result.monitored, 2);
      expect(
        log.messages,
        contains(
          'recoverbull.drive.discovery.partial listed=4 monitored=2 invalid=1 failed=0',
        ),
      );
      expect(log.messages.join(), isNot(contains('duplicate')));
      expect(log.messages.join(), isNot(contains('01')));
      expect((await store.driveBackups('old-account')), hasLength(2));
      expect((await store.driveCache('old-account')), hasLength(3));
      await db.close();
    },
  );

  test(
    'unchanged files avoid downloads and are re-adopted after disable',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('03')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      await discovery.execute();
      expect(drive.contentCalls, 1);
      await store.setEnabled(false);
      await store.setEnabled(true);
      await discovery.execute();
      expect(drive.contentCalls, 2);
      expect(await store.driveBackups('old-account'), hasLength(1));
      await db.close();
    },
  );

  test('disabled discovery performs no Drive work', () async {
    final (db, store) = await build();
    await store.setEnabled(false);
    final drive = _FakeDrive({'a': _valid('0d')});
    final result = await DiscoverDriveBackupsUsecase(
      drive: drive,
      store: store,
    ).execute();
    expect(result.status, DriveDiscoveryStatus.disabled);
    expect(drive.accountCalls, 0);
    expect(drive.filesCalls, 0);
    expect(drive.contentCalls, 0);
    expect(await store.monitoredBackups(), isEmpty);
    await db.close();
  });

  test('disable during an in-flight fetch prevents reconciliation', () async {
    final (db, store) = await build();
    final drive = _FakeDrive({'a': _valid('0e')});
    final gate = Completer<String>();
    drive.blockedContent = gate;
    final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
    final pending = discovery.execute();
    await drive.fetchStarted.future;
    await store.setEnabled(false);
    gate.complete(_valid('0e'));
    final result = await pending;
    expect(result.status, DriveDiscoveryStatus.disabled);
    expect(await store.monitoredBackups(), isEmpty);
    expect(await store.driveCache('old-account'), isEmpty);
    await db.close();
  });

  test('closed store is converted to a safe failed result', () async {
    final (db, store) = await build();
    await db.close();
    final log = _CaptureLog();
    final result = await DiscoverDriveBackupsUsecase(
      drive: _FakeDrive({'secret-id': _valid('12')}),
      store: store,
      log: log,
    ).execute();
    expect(result.status, DriveDiscoveryStatus.failed);
    expect(log.messages, ['recoverbull.drive.discovery.failed']);
    expect(log.messages.join(), isNot(contains('secret-id')));
    expect(log.messages.join(), isNot(contains('12')));
  });

  test(
    'modified and deleted files reconcile mappings and preserve duplicates',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('04'), 'b': _valid('04')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      drive.filesById['a'] = _valid('05');
      drive.modified['a'] = DateTime.utc(2026, 2);
      await discovery.execute();
      expect((await store.driveBackups('old-account')), hasLength(2));
      drive.filesById.remove('a');
      await discovery.execute();
      expect((await store.driveBackups('old-account')), hasLength(1));
      expect((await store.driveCache('old-account')), hasLength(1));
      drive.filesById.remove('b');
      await discovery.execute();
      expect(await store.driveBackups('old-account'), isEmpty);
      expect(await store.driveCache('old-account'), isEmpty);
      await db.close();
    },
  );

  test('transient content failure preserves the cached mapping', () async {
    final (db, store) = await build();
    final drive = _FakeDrive({'a': _valid('06')});
    final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
    await discovery.execute();
    final historicalDigest = (await store.driveBackups(
      'old-account',
    )).single.digest;
    final oldDigest = (await store.driveCache(
      'old-account',
    )).single.backupDigest;
    drive.filesById['a'] = _valid('11');
    drive.failContent = true;
    drive.modified['a'] = DateTime.utc(2026, 3);
    final result = await discovery.execute();
    expect(result.status, DriveDiscoveryStatus.partial);
    expect(result.failed, 1);
    expect(await store.driveBackups('old-account'), hasLength(1));
    expect(
      (await store.driveBackups('old-account')).single.digest,
      historicalDigest,
    );
    expect(await store.driveCache('old-account'), hasLength(1));
    expect(
      (await store.driveCache('old-account')).single.driveFileModifiedAt,
      isNull,
    );
    drive.failContent = false;
    final retried = await discovery.execute();
    final retriedCache = (await store.driveCache('old-account')).single;
    expect(retried.status, DriveDiscoveryStatus.complete);
    expect(drive.contentCalls, 3);
    expect(retriedCache.driveFileModifiedAt, DateTime.utc(2026, 3));
    expect(retriedCache.backupDigest, isNot(orderedEquals(oldDigest)));
    await db.close();
  });

  test(
    'invalid modified content preserves old metadata until a retry succeeds',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('0f')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      drive.filesById['a'] = '{"invalid":true}';
      drive.modified['a'] = DateTime.utc(2026, 4);
      final partial = await discovery.execute();
      expect(partial.status, DriveDiscoveryStatus.partial);
      expect(partial.invalid, 1);
      expect(await store.driveBackups('old-account'), hasLength(1));
      expect(
        (await store.driveCache('old-account')).single.driveFileModifiedAt,
        isNull,
      );
      drive.filesById['a'] = _valid('10');
      final complete = await discovery.execute();
      expect(complete.status, DriveDiscoveryStatus.complete);
      expect(drive.contentCalls, 3);
      expect(
        (await store.driveCache('old-account')).single.driveFileModifiedAt,
        DateTime.utc(2026, 4),
      );
      await db.close();
    },
  );

  test(
    'account and listing failures are failed and preserve existing state',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('09')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      drive.failListing = true;
      expect((await discovery.execute()).status, DriveDiscoveryStatus.failed);
      expect(await store.driveBackups('old-account'), hasLength(1));
      expect(await store.driveCache('old-account'), hasLength(1));
      drive.failListing = false;
      drive.failAccount = true;
      expect((await discovery.execute()).status, DriveDiscoveryStatus.failed);
      expect(await store.driveBackups('old-account'), hasLength(1));
      drive.failAccount = false;
      drive.filesById.clear();
      expect((await discovery.execute()).status, DriveDiscoveryStatus.empty);
      expect(await store.driveBackups('old-account'), isEmpty);
      expect(await store.driveCache('old-account'), isEmpty);
      await db.close();
    },
  );

  test(
    'missing silent account is unauthenticated without reconciliation',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('0c')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      drive.accountName = null;

      final result = await discovery.execute();

      expect(result.status, DriveDiscoveryStatus.unauthenticated);
      expect(result.listed, 0);
      expect(result.monitored, 0);
      expect(result.invalid, 0);
      expect(result.failed, 0);
      expect(await store.driveBackups('old-account'), hasLength(1));
      expect(await store.driveCache('old-account'), hasLength(1));
      await db.close();
    },
  );

  test(
    'repository metadata failure is failed and does not reconcile',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('0b')});
      await DiscoverDriveBackupsUsecase(drive: drive, store: store).execute();
      final repository = _MockGoogleDriveRepository();
      var entered = false;
      when(
        () => repository.withDiscoverySession<DriveDiscoveryResult>(any()),
      ).thenAnswer((invocation) {
        entered = true;
        final action =
            invocation.positionalArguments.single
                as Future<DriveDiscoveryResult> Function(
                  GoogleDriveDiscoverySession? session,
                );
        return action(_FailingDiscoverySession());
      });
      final result = await DiscoverDriveBackupsUsecase(
        drive: GoogleDriveBackupDiscoveryAdapter(repository),
        store: store,
      ).execute();
      expect(result.status, DriveDiscoveryStatus.failed);
      expect(entered, isTrue);
      expect(await store.driveBackups('old-account'), hasLength(1));
      expect(await store.driveCache('old-account'), hasLength(1));
      await db.close();
    },
  );

  test(
    'deleting one unchanged duplicate preserves the monitored digest',
    () async {
      final (db, store) = await build();
      final drive = _FakeDrive({'a': _valid('0a'), 'b': _valid('0a')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      drive.filesById.remove('a');
      await discovery.execute();
      expect(await store.driveBackups('old-account'), hasLength(1));
      expect(await store.driveCache('old-account'), hasLength(1));
      expect(drive.contentCalls, 2);
      await db.close();
    },
  );

  test(
    'account switch purges Drive rows but preserves local monitoring',
    () async {
      final (db, store) = await build();
      await store.registerBackup(List<int>.filled(32, 7));
      final drive = _FakeDrive({'a': _valid('07')});
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      drive.accountName = 'new-account';
      drive.filesById['b'] = _valid('08');
      await discovery.execute();
      final rows = await store.monitoredBackups();
      expect(rows.where((row) => row.driveAccount == 'old-account'), isEmpty);
      expect(
        rows.where((row) => row.driveAccount == 'new-account'),
        hasLength(1),
      );
      expect(rows.where((row) => row.driveAccount == null), hasLength(1));
      expect(await store.driveCache('old-account'), isEmpty);
      expect(await store.driveCache('new-account'), hasLength(2));
      await db.close();
    },
  );
}

String _valid(String byte) => jsonEncode({
  'version': 1,
  'created_at': 1780000000000,
  'id': List.filled(32, byte).join(),
  'salt': '000102030405060708090a0b0c0d0e0f',
  'ciphertext': base64Encode(List<int>.generate(64, (i) => i)),
  'path': "m/83696968'/0'/0'",
});

final class _FakeDrive implements RecoverBullDriveDiscoveryPort {
  final Map<String, String> filesById;
  final Map<String, DateTime> modified = {};
  String? accountName = 'old-account';
  bool failContent = false;
  bool failListing = false;
  bool failAccount = false;
  int contentCalls = 0;
  int accountCalls = 0;
  int filesCalls = 0;
  Completer<String>? blockedContent;
  final fetchStarted = Completer<void>();

  _FakeDrive(this.filesById);

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  ) async {
    if (failAccount) throw StateError('account unavailable');
    if (accountName == null) return action(null);
    return action(_FakeDiscoverySession(this));
  }

  Future<String?> account() async {
    accountCalls++;
    if (failAccount) throw StateError('account unavailable');
    return accountName;
  }

  Future<List<RecoverBullDriveFile>> files() async {
    filesCalls++;
    if (failListing) throw StateError('listing unavailable');
    return [
      for (final id in filesById.keys)
        RecoverBullDriveFile(
          id: id,
          createdTime: DateTime.utc(2026),
          modifiedTime: modified[id],
        ),
    ];
  }

  Future<String> content(String fileId) async {
    contentCalls++;
    if (!fetchStarted.isCompleted) fetchStarted.complete();
    if (blockedContent != null) return blockedContent!.future;
    if (failContent) throw StateError('transient');
    return filesById[fileId]!;
  }
}

final class _FakeDiscoverySession implements RecoverBullDriveDiscoverySession {
  final _FakeDrive drive;
  const _FakeDiscoverySession(this.drive);

  @override
  String get account => drive.accountName!;

  @override
  Future<List<RecoverBullDriveFile>> files() => drive.files();

  @override
  Future<String> content(String fileId) => drive.content(fileId);
}

final class _CaptureLog implements LogSink {
  final messages = <String>[];

  @override
  void fine(String message, {Object? error, StackTrace? trace}) =>
      messages.add(message);

  @override
  void info(String message, {Object? error, StackTrace? trace}) =>
      messages.add(message);

  @override
  void warning(String message, {Object? error, StackTrace? trace}) =>
      messages.add(message);

  @override
  void error(String message, {Object? error, StackTrace? trace}) =>
      messages.add(message);

  @override
  LogSink scoped(String scope) => this;
}

final class _MockGoogleDriveRepository extends Mock
    implements GoogleDriveRepository {}

final class _FailingDiscoverySession implements GoogleDriveDiscoverySession {
  @override
  String get account => 'old-account';

  @override
  Future<List<DriveFileMetadata>> fetchAllMetadata() =>
      Future.error(StateError('metadata unavailable'));

  @override
  Future<String> fetchRawFile(String fileId) =>
      Future.error(StateError('content unavailable'));
}
