import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/storage/database_encryption_key_store.dart';
import 'package:bb_mobile/core/storage/database_key_unavailable_exception.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The channel `flutter_secure_storage` talks over. Mocking it lets these
/// tests drive the exact keychain answers an iOS device gives — "not
/// unlocked since boot" versus "no such item" — which is the distinction
/// the whole store exists to preserve.
const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// `errSecInteractionNotAllowed`, as the plugin surfaces it.
PlatformException _lockedKeychain() =>
    PlatformException(code: 'Unexpected security result code', details: -25308);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Records every call so a test can assert on what was *not* done —
  /// the security-relevant assertion here is almost always "no write".
  late List<MethodCall> calls;

  void mockKeychain({
    String? storedValue,
    bool locked = false,
    bool captureWrites = true,
  }) {
    calls = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (locked) throw _lockedKeychain();
      switch (call.method) {
        case 'read':
          return storedValue;
        case 'write':
          if (captureWrites) storedValue = call.arguments['value'] as String;
          return null;
        case 'delete':
          storedValue = null;
          return null;
      }
      return null;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  String validKey() => base64UrlEncode(List<int>.filled(32, 7));

  group('loadOrCreate', () {
    test('returns the stored key when there is one', () async {
      final key = validKey();
      mockKeychain(storedValue: key);

      expect(
        await DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: true,
        ),
        key,
      );
      expect(calls.map((c) => c.method), isNot(contains('write')));
    });

    test('creates a key for a fresh install', () async {
      mockKeychain();

      final key = await DatabaseEncryptionKeyStore.loadOrCreate(
        hasDatabaseRequiringExistingKey: false,
      );

      expect(base64Url.decode(base64Url.normalize(key)), hasLength(32));
      expect(calls.map((c) => c.method), contains('write'));
    });

    test('fails closed rather than re-keying an existing database', () async {
      mockKeychain();

      await expectLater(
        DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: true,
        ),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
      expect(calls.map((c) => c.method), isNot(contains('write')));
    });

    test('a locked keychain is not mistaken for a missing key, and writes '
        'nothing even on a fresh install', () async {
      // The dangerous case: the keychain refuses to answer *and* we
      // believe there is no database yet (the databases could be there
      // but unopened, or a background wake could beat the first
      // unlock). Creating a key here is what silently orphans an
      // existing encrypted database, so the read must throw before the
      // creation path is ever reachable.
      mockKeychain(locked: true);

      await expectLater(
        DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: false,
        ),
        throwsA(isA<KeychainLockedException>()),
      );
      expect(calls.map((c) => c.method), isNot(contains('write')));
    });

    test('a locked keychain throws even when a database exists', () async {
      // Must be `KeychainLockedException`, not
      // `DatabaseKeyUnavailableException`: the first sends the user to a
      // retry screen, the second offers to delete their data.
      mockKeychain(locked: true);

      await expectLater(
        DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: true,
        ),
        throwsA(isA<KeychainLockedException>()),
      );
    });

    test('an unrelated keychain failure is not swallowed', () async {
      calls = [];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        throw PlatformException(code: 'some-other-failure');
      });

      await expectLater(
        DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: false,
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'some-other-failure',
          ),
        ),
      );
    });

    test('rejects a stored key of the wrong length', () async {
      mockKeychain(storedValue: base64UrlEncode(List<int>.filled(16, 1)));

      await expectLater(
        DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: true,
        ),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
    });

    test('rejects a stored key that is not base64url', () async {
      mockKeychain(storedValue: 'not base64!!');

      await expectLater(
        DatabaseEncryptionKeyStore.loadOrCreate(
          hasDatabaseRequiringExistingKey: true,
        ),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
    });
  });

  group('loadExisting', () {
    test('returns null for a genuinely absent key', () async {
      mockKeychain();
      expect(await DatabaseEncryptionKeyStore.loadExisting(), isNull);
    });

    test('throws rather than reporting a locked keychain as absent', () async {
      // A background task reading null would conclude "no database yet"
      // and carry on; it has to know to come back later instead.
      mockKeychain(locked: true);

      await expectLater(
        DatabaseEncryptionKeyStore.loadExisting(),
        throwsA(isA<KeychainLockedException>()),
      );
    });

    test('never writes', () async {
      mockKeychain();
      await DatabaseEncryptionKeyStore.loadExisting();
      expect(calls.map((c) => c.method), isNot(contains('write')));
    });
  });

  group('ensureKeyCanBeCreated', () {
    test('refuses to replace a missing key when a database exists', () {
      expect(
        () => DatabaseEncryptionKeyStore.ensureKeyCanBeCreated(
          hasDatabaseRequiringExistingKey: true,
        ),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
    });

    test('allows a key to be created for a new installation', () {
      expect(
        () => DatabaseEncryptionKeyStore.ensureKeyCanBeCreated(
          hasDatabaseRequiringExistingKey: false,
        ),
        returnsNormally,
      );
    });
  });

  group('hasDatabaseRequiringExistingKey', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('database-key-policy');
    });

    tearDown(() {
      directory.deleteSync(recursive: true);
    });

    File file(String name, List<int> bytes) =>
        File('${directory.path}/$name')..writeAsBytesSync(bytes);

    test('allows the first key to be created for plaintext upgrades', () async {
      final main = file('bullbitcoin_sqlite.sqlite', [
        ...utf8.encode('SQLite format 3\u0000'),
        ...List<int>.filled(32, 0),
      ]);
      final payjoin = file('payjoin.sqlite', [
        ...utf8.encode('SQLite format 3\u0000'),
        ...List<int>.filled(32, 0),
      ]);

      expect(
        await DatabaseEncryptionKeyStore.hasDatabaseRequiringExistingKey([
          main,
          payjoin,
        ]),
        isFalse,
      );
    });

    test('requires the old key for an encrypted database', () async {
      final encrypted = file(
        'bullbitcoin_sqlite.sqlite',
        List<int>.generate(48, (index) => index + 1),
      );

      expect(
        await DatabaseEncryptionKeyStore.hasDatabaseRequiringExistingKey([
          encrypted,
        ]),
        isTrue,
      );
    });

    test('fails closed for a corrupt or truncated database', () async {
      final corrupt = file('bullbitcoin_sqlite.sqlite', [1, 2, 3]);

      expect(
        await DatabaseEncryptionKeyStore.hasDatabaseRequiringExistingKey([
          corrupt,
        ]),
        isTrue,
      );
    });

    test('ignores database paths that do not exist', () async {
      expect(
        await DatabaseEncryptionKeyStore.hasDatabaseRequiringExistingKey([
          File('${directory.path}/absent.sqlite'),
        ]),
        isFalse,
      );
    });
  });
}
