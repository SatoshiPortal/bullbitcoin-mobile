import 'dart:io';

import 'package:bb_mobile/core/storage/backup_exclusion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _channel = MethodChannel('bullbitcoin.com/backup_exclusion');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('backup_exclusion');
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  String touch(String name) {
    final file = File(p.join(directory.path, name))..writeAsStringSync('x');
    return file.path;
  }

  group('resolvePaths', () {
    test('expands a database path into its existing sidecars', () {
      final main = touch('bullbitcoin_sqlite.sqlite');
      touch('bullbitcoin_sqlite.sqlite-wal');
      touch('bullbitcoin_sqlite.sqlite-shm');

      expect(BackupExclusion.resolvePaths([main]), [
        main,
        '$main-wal',
        '$main-shm',
      ]);
    });

    test('skips files that do not exist yet', () {
      // The realistic first-launch shape: the main database is open but
      // has not been written to, and the payjoin database is opened
      // lazily. Handing a missing path to the native side would throw.
      final main = touch('bullbitcoin_sqlite.sqlite');
      final payjoin = p.join(directory.path, 'payjoin.sqlite');

      expect(BackupExclusion.resolvePaths([main, payjoin]), [main]);
    });

    test('returns nothing when no database exists', () {
      expect(
        BackupExclusion.resolvePaths([p.join(directory.path, 'absent.sqlite')]),
        isEmpty,
      );
    });
  });

  group('excludeDatabases', () {
    test('does not touch the channel off iOS', () async {
      // Android has no equivalent flag — `android:allowBackup` and the
      // data-extraction rules cover it at the manifest level — so this
      // must stay a silent no-op rather than a per-launch warning.
      var invoked = false;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        invoked = true;
        return null;
      });

      await BackupExclusion.excludeDatabases([touch('a.sqlite')]);

      expect(invoked, Platform.isIOS);
    });

    test('a failing channel never breaks startup', () async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        throw PlatformException(code: 'exclude-failed');
      });

      await expectLater(
        BackupExclusion.excludeDatabases([touch('a.sqlite')]),
        completes,
      );
    });
  });
}
