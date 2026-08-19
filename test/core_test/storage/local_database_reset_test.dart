import 'dart:io';

import 'package:bb_mobile/core/storage/local_database_reset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _keychain = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory directory;
  late List<MethodCall> keychainCalls;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('local_database_reset');
    keychainCalls = [];
    messenger.setMockMethodCallHandler(_keychain, (call) async {
      keychainCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_keychain, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  File touch(String name) =>
      File(p.join(directory.path, name))..writeAsStringSync('x');

  test('removes every database file, sidecar and migration leftover', () async {
    final main = p.join(directory.path, 'bullbitcoin_sqlite.sqlite');
    final payjoin = p.join(directory.path, 'payjoin.sqlite');
    final created = [
      touch('bullbitcoin_sqlite.sqlite'),
      touch('bullbitcoin_sqlite.sqlite-wal'),
      touch('bullbitcoin_sqlite.sqlite-shm'),
      // A crashed encryption migration leaves these behind. Missing them
      // would resurrect the unreadable database on the next launch,
      // because the recovery pass restores `.plaintext-backup`.
      touch('bullbitcoin_sqlite.sqlite.encryption-tmp'),
      touch('bullbitcoin_sqlite.sqlite.plaintext-backup'),
      touch('payjoin.sqlite'),
      touch('payjoin.sqlite-wal'),
      touch('payjoin.sqlite-shm'),
    ];

    await LocalDatabaseReset.run([main, payjoin]);

    for (final file in created) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
  });

  test('deletes the encryption key last, and only once', () async {
    final main = p.join(directory.path, 'bullbitcoin_sqlite.sqlite');
    touch('bullbitcoin_sqlite.sqlite');

    await LocalDatabaseReset.run([main]);

    expect(keychainCalls.map((c) => c.method), ['delete']);
    expect(File(main).existsSync(), isFalse);
  });

  test('leaves unrelated files in the directory alone', () async {
    final main = p.join(directory.path, 'bullbitcoin_sqlite.sqlite');
    touch('bullbitcoin_sqlite.sqlite');
    // Seeds and logs are not ours to delete: wiping secure storage here
    // would turn "your local cache is unreadable" into "your funds are
    // gone".
    final logs = touch('bull_logs.tsv');

    await LocalDatabaseReset.run([main]);

    expect(logs.existsSync(), isTrue);
  });

  test(
    'retains the encryption key when a database cannot be deleted',
    () async {
      final main = p.join(directory.path, 'bullbitcoin_sqlite.sqlite');
      touch('bullbitcoin_sqlite.sqlite');

      await expectLater(
        LocalDatabaseReset.run([
          main,
        ], deleteFile: (_) async => throw const FileSystemException('locked')),
        throwsA(isA<FileSystemException>()),
      );

      expect(keychainCalls, isEmpty);
    },
  );

  test('is a no-op when there is nothing on disk', () async {
    await LocalDatabaseReset.run([p.join(directory.path, 'absent.sqlite')]);
    expect(keychainCalls.map((c) => c.method), ['delete']);
  });
}
