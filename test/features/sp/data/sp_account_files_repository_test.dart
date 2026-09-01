import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/data/sp_account_files_repository.dart';
import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Filesystem-level tests for the on-disk account lifecycle. Each method here is
// a single file operation; the order a revoke or a recreate runs them in is the
// use case's business and is covered by RevokeSpWalletUsecase's own test.
void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sp_files_test_');
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

  SpAccountFilesRepository makeRepo() =>
      SpAccountFilesRepository(files: SpAccountFilesDatasource());

  Directory accountDirOf() =>
      Directory('${tempDir.path}/${SpStorageNames.accountName}');
  File sentinelOf() =>
      File('${accountDirOf().path}/${SpStorageNames.revokedSentinelFile}');
  // A backup dir as the datasource names them: the account name, the suffix,
  // then the microsecond stamp that orders them.
  Directory backupDirOf(int stamp) =>
      Directory('${tempDir.path}/${SpStorageNames.accountName}.backup-$stamp');

  group('accountDirExists', () {
    test('false before the dir is created, true after', () async {
      final repo = makeRepo();
      expect(
        (await repo.accountDirExists() as Ok<bool, SpFailure>).value,
        isFalse,
      );

      accountDirOf().createSync();

      expect(
        (await repo.accountDirExists() as Ok<bool, SpFailure>).value,
        isTrue,
      );
    });
  });

  group('hasRevokedSentinel', () {
    test('false when no account dir', () async {
      expect(
        (await makeRepo().hasRevokedSentinel() as Ok<bool, SpFailure>).value,
        isFalse,
      );
    });

    test('true when the sentinel file is present', () async {
      accountDirOf().createSync();
      sentinelOf().writeAsStringSync('revoked');

      expect(
        (await makeRepo().hasRevokedSentinel() as Ok<bool, SpFailure>).value,
        isTrue,
      );
    });
  });

  group('writeRevokedSentinel', () {
    test('writes the sentinel into the account dir', () async {
      accountDirOf().createSync();

      expect(
        await makeRepo().writeRevokedSentinel(),
        isA<Ok<void, SpFailure>>(),
      );
      expect(sentinelOf().existsSync(), isTrue);
    });

    test('skipIfPresent leaves an existing sentinel untouched', () async {
      accountDirOf().createSync();
      sentinelOf().writeAsStringSync('original');

      await makeRepo().writeRevokedSentinel(skipIfPresent: true);

      expect(
        sentinelOf().readAsStringSync(),
        'original',
        reason: 'the partial-delete recovery must not rewrite the sentinel',
      );
    });
  });

  group('deleteAccountDir', () {
    test('deletes the account dir and everything under it', () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('db');
      sentinelOf().writeAsStringSync('revoked');

      expect(await makeRepo().deleteAccountDir(), isA<Ok<void, SpFailure>>());
      expect(accountDir.existsSync(), isFalse);
    });

    test('is a no-op when the dir is absent', () async {
      expect(await makeRepo().deleteAccountDir(), isA<Ok<void, SpFailure>>());
      expect(accountDirOf().existsSync(), isFalse);
    });
  });

  group('backup / restore / discard', () {
    test('backupAccountDir moves the dir aside; restoreAccountDir brings it '
        'back', () async {
      final accountDir = accountDirOf()..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('old');

      final repo = makeRepo();
      expect(
        (await repo.backupAccountDir() as Ok<bool, SpFailure>).value,
        isTrue,
      );
      expect(accountDir.existsSync(), isFalse);

      expect(
        (await repo.restoreAccountDir() as Ok<bool, SpFailure>).value,
        isTrue,
      );
      expect(accountDir.existsSync(), isTrue);
      expect(
        File('${accountDir.path}/account.sqlite').readAsStringSync(),
        'old',
      );
    });

    test(
      'backupAccountDir returns false with no dir; restore then no-ops',
      () async {
        final repo = makeRepo();
        expect(
          (await repo.backupAccountDir() as Ok<bool, SpFailure>).value,
          isFalse,
        );
        expect(
          (await repo.restoreAccountDir() as Ok<bool, SpFailure>).value,
          isFalse,
        );
      },
    );

    test(
      'restoreAccountDir deletes a partial new dir before restoring backup',
      () async {
        final accountDir = accountDirOf()..createSync();
        File('${accountDir.path}/account.sqlite').writeAsStringSync('old');

        final repo = makeRepo();
        await repo.backupAccountDir();
        // A partial recreate left a fresh dir behind.
        accountDirOf().createSync();
        File('${accountDirOf().path}/partial').writeAsStringSync('junk');

        expect(
          (await repo.restoreAccountDir() as Ok<bool, SpFailure>).value,
          isTrue,
        );
        expect(
          File('${accountDir.path}/account.sqlite').readAsStringSync(),
          'old',
        );
        expect(File('${accountDir.path}/partial').existsSync(), isFalse);
      },
    );

    test('discardBackup removes the backup dir', () async {
      accountDirOf().createSync();
      final repo = makeRepo();
      await repo.backupAccountDir();

      expect(await repo.discardBackup(), isA<Ok<void, SpFailure>>());

      final backups = tempDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('.backup-'))
          .toList();
      expect(backups, isEmpty);
    });
  });

  group('deleteOrphanBackups', () {
    test('sweeps every leftover backup so no wallet copy stays', () async {
      final first = backupDirOf(1)..createSync();
      File('${first.path}/account.sqlite').writeAsStringSync('one');
      final second = backupDirOf(2)..createSync();
      File('${second.path}/account.sqlite').writeAsStringSync('two');

      expect(
        await makeRepo().deleteOrphanBackups(),
        isA<Ok<void, SpFailure>>(),
      );
      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isFalse);
    });
  });

  group('adoptNewestBackup', () {
    test('restores the newest backup and drops the older ones', () async {
      final older = backupDirOf(1)..createSync();
      File('${older.path}/account.sqlite').writeAsStringSync('older');
      final newest = backupDirOf(2)..createSync();
      File('${newest.path}/account.sqlite').writeAsStringSync('newest');

      final adopted = await makeRepo().adoptNewestBackup();

      expect((adopted as Ok<bool, SpFailure>).value, isTrue);
      expect(
        File('${accountDirOf().path}/account.sqlite').readAsStringSync(),
        'newest',
      );
      expect(older.existsSync(), isFalse);
      expect(newest.existsSync(), isFalse);
    });

    test('does nothing when the account dir is still there', () async {
      accountDirOf().createSync();
      File('${accountDirOf().path}/account.sqlite').writeAsStringSync('live');
      final backup = backupDirOf(1)..createSync();
      File('${backup.path}/account.sqlite').writeAsStringSync('stale');

      final adopted = await makeRepo().adoptNewestBackup();

      expect((adopted as Ok<bool, SpFailure>).value, isFalse);
      expect(
        File('${accountDirOf().path}/account.sqlite').readAsStringSync(),
        'live',
        reason: 'a live account dir must never be overwritten by a backup',
      );
      expect(backup.existsSync(), isTrue);
    });

    test('does nothing when there is no backup at all', () async {
      final adopted = await makeRepo().adoptNewestBackup();

      expect((adopted as Ok<bool, SpFailure>).value, isFalse);
      expect(accountDirOf().existsSync(), isFalse);
    });
  });
}
