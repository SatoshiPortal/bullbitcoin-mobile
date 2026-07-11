import 'dart:io';

import 'package:bb_mobile/features/sp/data/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Filesystem-level tests for the on-disk account lifecycle the SP use cases
// delegate to (T4.5). No live FFI session is established: these methods either
// run with no session or (for the sentinel-before-dispose ordering) use a
// subclass that fakes the session so dispose never touches the Rust side.
// Effective uid via `id -u`; Dart exposes no geteuid. -1 when it can't be read
// (treated as non-root so the failure assertion still runs where it is valid).
int _euid() {
  try {
    final r = Process.runSync('id', ['-u']);
    if (r.exitCode != 0) return -1;
    return int.tryParse((r.stdout as String).trim()) ?? -1;
  } catch (_) {
    return -1;
  }
}

class _RepoWithFakeSession extends BwkSpAccountRepository {
  _RepoWithFakeSession(this.sentinelPath);

  final String sentinelPath;
  bool session = true;
  bool sentinelPresentAtDispose = false;

  @override
  bool get hasSession => session;

  @override
  Future<void> dispose() async {
    sentinelPresentAtDispose = File(sentinelPath).existsSync();
    session = false;
  }
}

// Fakes the FFI session disposal so _runDispose can be exercised with no live
// Rust account. [shouldThrow] models a "dispose timed out" (inner lock still
// held); otherwise a clean session teardown.
class _RepoWithDisposableSession extends BwkSpAccountRepository {
  _RepoWithDisposableSession({this.shouldThrow = false});

  final bool shouldThrow;
  bool session = true;

  @override
  bool get hasSession => session;

  @override
  Future<void> disposeCurrentSession() async {
    if (shouldThrow) throw StateError('dispose timed out');
    session = false;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sp_repo_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return tempDir.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // best-effort; some tests intentionally leave locked state
      }
    }
  });

  Directory accountDirOf() =>
      Directory('${tempDir.path}/${SpConfig.accountName}');
  File sentinelOf() =>
      File('${accountDirOf().path}/${SpConfig.revokedSentinelFile}');

  group('hasRevokedSentinel', () {
    test('false when no account dir', () async {
      final repo = BwkSpAccountRepository();
      expect(await repo.hasRevokedSentinel(), isFalse);
    });

    test('true when the sentinel file is present', () async {
      accountDirOf().createSync();
      sentinelOf().writeAsStringSync('revoked');
      final repo = BwkSpAccountRepository();
      expect(await repo.hasRevokedSentinel(), isTrue);
    });
  });

  group('revokeOnDisk', () {
    test('writes the sentinel then deletes the account dir', () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('db');

      await BwkSpAccountRepository().revokeOnDisk();

      expect(accountDir.existsSync(), isFalse);
    });

    test('writes the sentinel BEFORE disposing the live session (T1.3)',
        () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('db');

      final repo = _RepoWithFakeSession(sentinelOf().path);
      await repo.revokeOnDisk();

      expect(
        repo.sentinelPresentAtDispose,
        isTrue,
        reason: 'sentinel must be on disk before the session is torn down',
      );
      expect(accountDir.existsSync(), isFalse);
    });

    test('on a delete failure the sentinel survives, SpSetupChanged is '
        'emitted, and the error is rethrown', () async {
      // Root ignores the read-only bit, so `chmod -w` cannot block the delete
      // and the rethrow would never fire; skip instead of asserting nothing.
      if (_euid() == 0) {
        markTestSkipped('runs as root (euid==0); chmod -w cannot block delete');
        return;
      }
      final accountDir = accountDirOf()..createSync();
      final lockedSubdir = Directory('${accountDir.path}/locked')..createSync();
      File('${lockedSubdir.path}/account.sqlite').writeAsStringSync('db');
      final chmod = await Process.run('chmod', ['-w', lockedSubdir.path]);
      if (chmod.exitCode != 0) {
        markTestSkipped('chmod unavailable; cannot simulate a delete failure');
        return;
      }
      addTearDown(() async {
        await Process.run('chmod', ['+w', lockedSubdir.path]);
      });

      final repo = BwkSpAccountRepository();
      final setupChanged = repo.updates
          .where((u) => u is SpSetupChanged)
          .first;

      Object? caught;
      try {
        await repo.revokeOnDisk();
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull, reason: 'delete failure must rethrow');
      expect(
        sentinelOf().existsSync(),
        isTrue,
        reason: 'sentinel must survive a partial delete',
      );
      await setupChanged; // completes only if the event was emitted
    });

    test('is a no-op when the account dir is already gone', () async {
      await BwkSpAccountRepository().revokeOnDisk();
      expect(accountDirOf().existsSync(), isFalse);
    });
  });

  group('backup / restore / discard', () {
    test('backupAccountDir moves the dir aside; restoreAccountDir brings it '
        'back', () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('old');

      final repo = BwkSpAccountRepository();
      expect(await repo.backupAccountDir(), isTrue);
      expect(accountDir.existsSync(), isFalse);

      expect(await repo.restoreAccountDir(), isTrue);
      expect(accountDir.existsSync(), isTrue);
      expect(
        File('${accountDir.path}/account.sqlite').readAsStringSync(),
        'old',
      );
    });

    test('backupAccountDir returns false with no dir; restore then no-ops',
        () async {
      final repo = BwkSpAccountRepository();
      expect(await repo.backupAccountDir(), isFalse);
      expect(await repo.restoreAccountDir(), isFalse);
    });

    test('restoreAccountDir deletes a partial new dir before restoring backup',
        () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('old');

      final repo = BwkSpAccountRepository();
      await repo.backupAccountDir();
      // A partial recreate left a fresh dir behind.
      accountDirOf().createSync();
      File('${accountDirOf().path}/partial').writeAsStringSync('junk');

      expect(await repo.restoreAccountDir(), isTrue);
      expect(
        File('${accountDir.path}/account.sqlite').readAsStringSync(),
        'old',
      );
      expect(File('${accountDir.path}/partial').existsSync(), isFalse);
    });

    test('discardBackup removes the backup dir', () async {
      accountDirOf().createSync();
      final repo = BwkSpAccountRepository();
      await repo.backupAccountDir();

      await repo.discardBackup();

      final backups = tempDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('.backup-'))
          .toList();
      expect(backups, isEmpty);
    });
  });

  group('dispose stream teardown', () {
    test('a clean session dispose tears down the notification streams',
        () async {
      final repo = _RepoWithDisposableSession();

      await repo.dispose();

      expect(repo.notifStreamTornDown, isTrue);
    });

    test('a timed-out session dispose keeps the streams and session live',
        () async {
      final repo = _RepoWithDisposableSession(shouldThrow: true);

      await expectLater(repo.dispose(), throwsA(isA<StateError>()));

      // The stream plumbing is NOT torn down, so the still-live session keeps
      // pushing notifications instead of going dark on a transient timeout.
      expect(repo.notifStreamTornDown, isFalse);
      expect(repo.hasSession, isTrue);
      expect(repo.isScanningCached, isFalse);
    });
  });

  group('wipeStaleAccountDir', () {
    test('deletes a stale account dir', () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('db');
      sentinelOf().writeAsStringSync('revoked');

      await BwkSpAccountRepository().wipeStaleAccountDir();

      expect(accountDir.existsSync(), isFalse);
    });

    test('is a no-op when the dir is absent', () async {
      await BwkSpAccountRepository().wipeStaleAccountDir();
      expect(accountDirOf().existsSync(), isFalse);
    });
  });
}
