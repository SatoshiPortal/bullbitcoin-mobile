import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'dart:convert';

import '../sp_fakes.dart';
import 'dart:io';

import 'package:primitives/primitives.dart';
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

  void markVerified(Directory directory) {
    final source = spSourceBinding;
    File(
      '${directory.path}/${SpStorageNames.identityMarker}',
    ).writeAsStringSync(
      jsonEncode({
        'version': 1,
        'network': 'regtest',
        'walletId': source.walletId,
        'secretId': source.secretId,
        'externalDescriptor': source.externalDescriptor,
        'internalDescriptor': source.internalDescriptor,
        'spAddress': source.spAddress,
        'status': 'verified',
      }),
    );
  }

  test(
    'legacy directory is detected and never deleted by V2 revoke cleanup',
    () async {
      final legacy = Directory(
        '${tempDir.path}/${SpStorageNames.legacyAccountName}',
      )..createSync();
      File('${legacy.path}/account.sqlite').writeAsStringSync('historical');
      final repo = makeRepo();
      expect((await repo.hasLegacyData() as Ok<bool, SpFailure>).value, isTrue);
      await repo.deleteOrphanBackups(null);
      await repo.deleteAccountDir();
      expect(
        File('${legacy.path}/account.sqlite').readAsStringSync(),
        'historical',
      );
    },
  );

  group('V2 identity marker', () {
    test('pending creation is not accepted as a verified account', () async {
      final repo = makeRepo();
      expect(
        await repo.createAccountDir(spBackendConfig()),
        isA<Ok<void, SpFailure>>(),
      );
      expect(
        await repo.verifyAccountIdentity(spBackendConfig()),
        isA<Err<void, SpFailure>>(),
      );
      expect(
        await repo.verifyPendingIdentity(spBackendConfig()),
        isA<Ok<void, SpFailure>>(),
      );
      expect(accountDirOf().existsSync(), isTrue);
    });

    test(
      'only a matching pending marker can be committed after verification',
      () async {
        final datasource = SpAccountFilesDatasource();
        final repo = SpAccountFilesRepository(files: datasource);
        await repo.createAccountDir(spBackendConfig());
        await datasource.commitAccountIdentity(spBackendConfig());
        expect(
          await repo.verifyAccountIdentity(spBackendConfig()),
          isA<Ok<void, SpFailure>>(),
        );
      },
    );

    test(
      'an absent marker is never repaired on an existing directory',
      () async {
        accountDirOf().createSync();
        final repo = makeRepo();
        expect(
          await repo.createAccountDir(spBackendConfig()),
          isA<Err<void, SpFailure>>(),
        );
        expect(
          await repo.verifyAccountIdentity(spBackendConfig()),
          isA<Err<void, SpFailure>>(),
        );
        expect(
          File(
            '${accountDirOf().path}/${SpStorageNames.identityMarker}',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('incomplete staging blocks adoption and stays untouched', () async {
      final stage = Directory('${tempDir.path}/sp_v2.new-interrupted')
        ..createSync();
      final backup = backupDirOf(1)..createSync();
      markVerified(backup);
      expect(
        await makeRepo().adoptNewestBackup(spBackendConfig()),
        isA<Err<bool, SpFailure>>(),
      );
      expect(stage.existsSync(), isTrue);
      expect(backup.existsSync(), isTrue);
    });

    test(
      'a marker symlink is refused without following or changing its target',
      () async {
        final account = accountDirOf()..createSync();
        final outside = File('${tempDir.path}/outside-marker')
          ..writeAsStringSync('unchanged');
        Link(
          '${account.path}/${SpStorageNames.identityMarker}',
        ).createSync(outside.path);
        expect(
          await makeRepo().verifyAccountIdentity(spBackendConfig()),
          isA<Err<void, SpFailure>>(),
        );
        expect(outside.readAsStringSync(), 'unchanged');
      },
    );

    test('resume accepts one matching backup and preserves it', () async {
      final backup = backupDirOf(1)..createSync();
      markVerified(backup);
      expect(
        await makeRepo().verifyResumeBackups(spBackendConfig()),
        isA<Ok<void, SpFailure>>(),
      );
      expect(backup.existsSync(), isTrue);
    });

    test('resume rejects a backup whose marker does not match', () async {
      final backup = backupDirOf(1)..createSync();
      expect(
        await makeRepo().verifyResumeBackups(spBackendConfig()),
        isA<Err<void, SpFailure>>(),
      );
      expect(backup.existsSync(), isTrue);
    });

    test('a backup symlink is not ignored or followed', () async {
      final outside = Directory('${tempDir.path}/outside')..createSync();
      final link = Link(backupDirOf(1).path)..createSync(outside.path);
      expect(
        await makeRepo().adoptNewestBackup(spBackendConfig()),
        isA<Err<bool, SpFailure>>(),
      );
      expect(link.existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
    });

    test('a mismatched marker is preserved and never adopted', () async {
      final backup = backupDirOf(1)..createSync();
      markVerified(backup);
      final mismatch = SpBackendConfig(
        network: BitcoinNetwork.mainnet,
        source: spSourceBinding,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );
      expect(
        await makeRepo().adoptNewestBackup(mismatch),
        isA<Err<bool, SpFailure>>(),
      );
      expect(backup.existsSync(), isTrue);
      expect(accountDirOf().existsSync(), isFalse);
    });
  });

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
      markVerified(accountDir);
      File('${accountDir.path}/account.sqlite').writeAsStringSync('old');

      final repo = makeRepo();
      expect(
        (await repo.backupAccountDir(spBackendConfig()) as Ok<bool, SpFailure>)
            .value,
        isTrue,
      );
      expect(accountDir.existsSync(), isFalse);

      expect(
        (await repo.restoreAccountDir(spBackendConfig()) as Ok<bool, SpFailure>)
            .value,
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
          (await repo.backupAccountDir(spBackendConfig())
                  as Ok<bool, SpFailure>)
              .value,
          isFalse,
        );
        expect(
          (await repo.restoreAccountDir(spBackendConfig())
                  as Ok<bool, SpFailure>)
              .value,
          isFalse,
        );
      },
    );

    test(
      'restoreAccountDir preserves a partial new directory without a marker',
      () async {
        final accountDir = accountDirOf()..createSync();
        markVerified(accountDir);
        File('${accountDir.path}/account.sqlite').writeAsStringSync('old');
        final repo = makeRepo();
        await repo.backupAccountDir(spBackendConfig());
        accountDirOf().createSync();
        File('${accountDirOf().path}/partial').writeAsStringSync('junk');
        expect(
          await repo.restoreAccountDir(spBackendConfig()),
          isA<Err<bool, SpFailure>>(),
        );
        expect(File('${accountDirOf().path}/partial').existsSync(), isTrue);
        expect(
          tempDir.listSync().whereType<Directory>().any(
            (d) => d.path.contains('.backup-'),
          ),
          isTrue,
        );
      },
    );

    test('discardBackup removes the backup dir', () async {
      accountDirOf().createSync();
      markVerified(accountDirOf());
      final repo = makeRepo();
      await repo.backupAccountDir(spBackendConfig());

      expect(
        await repo.discardBackup(spBackendConfig()),
        isA<Ok<void, SpFailure>>(),
      );

      final backups = tempDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('.backup-'))
          .toList();
      expect(backups, isEmpty);
    });
  });

  group('deleteOrphanBackups', () {
    test(
      'preserves multiple backups until their identity is resolved',
      () async {
        final first = backupDirOf(1)..createSync();
        File('${first.path}/account.sqlite').writeAsStringSync('one');
        final second = backupDirOf(2)..createSync();
        File('${second.path}/account.sqlite').writeAsStringSync('two');

        expect(
          await makeRepo().deleteOrphanBackups(spBackendConfig()),
          isA<Err<void, SpFailure>>(),
        );
        expect(first.existsSync(), isTrue);
        expect(second.existsSync(), isTrue);
      },
    );
  });

  group('adoptNewestBackup', () {
    test(
      'multiple backups are preserved without choosing by timestamp',
      () async {
        final older = backupDirOf(1)..createSync();
        final newest = backupDirOf(2)..createSync();
        markVerified(older);
        markVerified(newest);
        expect(
          await makeRepo().adoptNewestBackup(spBackendConfig()),
          isA<Err<bool, SpFailure>>(),
        );
        expect(older.existsSync(), isTrue);
        expect(newest.existsSync(), isTrue);
        expect(accountDirOf().existsSync(), isFalse);
      },
    );

    test(
      'multiple backups block reopening even with an account directory',
      () async {
        final account = accountDirOf()..createSync();
        markVerified(account);
        final first = backupDirOf(1)..createSync();
        final second = backupDirOf(2)..createSync();
        markVerified(first);
        markVerified(second);
        expect(
          await makeRepo().adoptNewestBackup(spBackendConfig()),
          isA<Err<bool, SpFailure>>(),
        );
        expect(account.existsSync(), isTrue);
        expect(first.existsSync(), isTrue);
        expect(second.existsSync(), isTrue);
      },
    );

    test('adopts one backup only when its marker matches', () async {
      final backup = backupDirOf(1)..createSync();
      markVerified(backup);
      final adopted = await makeRepo().adoptNewestBackup(spBackendConfig());
      expect((adopted as Ok<bool, SpFailure>).value, isTrue);
      expect(accountDirOf().existsSync(), isTrue);
    });

    test('does nothing when the account dir is still there', () async {
      accountDirOf().createSync();
      File('${accountDirOf().path}/account.sqlite').writeAsStringSync('live');
      final backup = backupDirOf(1)..createSync();
      File('${backup.path}/account.sqlite').writeAsStringSync('stale');

      final adopted = await makeRepo().adoptNewestBackup(spBackendConfig());

      expect((adopted as Ok<bool, SpFailure>).value, isFalse);
      expect(
        File('${accountDirOf().path}/account.sqlite').readAsStringSync(),
        'live',
        reason: 'a live account dir must never be overwritten by a backup',
      );
      expect(backup.existsSync(), isTrue);
    });

    test('does nothing when there is no backup at all', () async {
      final adopted = await makeRepo().adoptNewestBackup(spBackendConfig());

      expect((adopted as Ok<bool, SpFailure>).value, isFalse);
      expect(accountDirOf().existsSync(), isFalse);
    });
  });
}
