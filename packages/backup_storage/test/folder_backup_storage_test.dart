import 'dart:async';

import 'package:backup_storage/backup_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/storage_contract.dart' show ok, storageContract;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bullbitcoin.backup_storage/folder');
  const mimeType = 'application/vnd.bull.backup+bip138';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late _Store store;
  late _FolderPlatform platform;
  late FolderBackupStorage storage;
  final bytes = Uint8List.fromList([0, 255, 13, 10]);

  setUp(() {
    store = _Store();
    platform = _FolderPlatform();
    storage = FolderBackupStorage(store);
    messenger.setMockMethodCallHandler(channel, platform.invoke);
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<StorageSession> select() async =>
      ok(await storage.authorize(interactive: true));

  group('Folder contract', () {
    setUp(() async {
      (await select()).dispose();
    });

    storageContract(() => storage, matchByExtension: true);
  });

  Future<StoredObject> create(StorageSession session) async => ok(
    await session.create(
      name: 'bull-data-one.bip138',
      mimeType: mimeType,
      bytes: bytes,
    ),
  );

  test(
    'noninteractive authorization stays headless, including after restart',
    () async {
      expect(
        _failure(await storage.authorize(interactive: false)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      expect(platform.calls, isEmpty);
      final first = await select();
      first.dispose();

      final restarted = FolderBackupStorage(store);
      final background = ok(await restarted.authorize(interactive: false));
      expect(background.account.id, first.account.id);
      expect(platform.calls, ['pick', 'inspect']);
    },
  );

  test(
    'round trip verifies bytes, applies literal prefix and filters extension',
    () async {
      final session = await select();
      final object = await create(session);
      expect(object.durability, Durability.durable);
      expect(platform.calls, ['pick', 'create', 'read']);
      expect(ok(await session.read(object, maxBytes: bytes.length)), bytes);
      expect(
        _failure(await session.read(object, maxBytes: bytes.length - 1)),
        isA<BackupStorageTooLargeFailure>(),
      );
      platform.files['bull-data-unrelated.json'] = bytes;
      platform.files['foreign.bip138'] = bytes;
      final listed = ok(
        await session.list(mimeType: 'ignored', namePrefix: 'bull-data-'),
      );
      expect(listed.map((item) => item.id), [object.id]);
      expect(listed.single.durability, Durability.durable);
      expect(
        ok(await session.list(mimeType: mimeType, namePrefix: 'bull-data.*')),
        isEmpty,
      );
      ok(await session.delete(object));
      expect(
        ok(await session.list(mimeType: mimeType, namePrefix: 'bull-data-')),
        isEmpty,
      );
      expect(
        _failure(await session.read(object, maxBytes: bytes.length)),
        isA<BackupStorageNotFoundFailure>(),
      );
    },
  );

  test(
    'write receipts survive restart and never certify changed or foreign bytes',
    () async {
      final first = await select();
      final object = await create(first);
      first.dispose();
      final background = ok(
        await FolderBackupStorage(store).authorize(interactive: false),
      );
      final before = ok(await background.list(mimeType: mimeType));
      expect(before.single.id, object.id);
      expect(before.single.durability, Durability.durable);

      platform.files[object.name] = Uint8List.fromList([1, 2, 3, 4]);
      platform.files['foreign.bip138'] = bytes;
      final after = ok(await background.list(mimeType: mimeType));
      expect(after.map((item) => item.durability), [
        Durability.pending,
        Durability.pending,
      ]);
    },
  );

  test(
    'a new bookmark for the same folder preserves its identity and receipts',
    () async {
      final first = await select();
      final object = await create(first);

      platform.tokenOverride = 'new-bookmark';
      final reopened = await select();
      expect(reopened.account.id, first.account.id);
      final listed = ok(await reopened.list(mimeType: mimeType));
      expect(listed.single.id, object.id);
      expect(listed.single.durability, Durability.durable);
    },
  );

  test('mismatching read-back leaves the ambiguous file pending', () async {
    final session = await select();
    platform.corruptWrites = true;
    expect(
      _failure(
        await session.create(
          name: 'bull-data-one.bip138',
          mimeType: mimeType,
          bytes: bytes,
        ),
      ),
      isA<BackupStorageUnavailableFailure>(),
    );
    expect(
      ok(await session.list(mimeType: mimeType)).single.durability,
      Durability.pending,
    );
  });

  test(
    'cancellation preserves the grant and reselection invalidates old sessions',
    () async {
      final first = await select();
      platform.nextError = 'cancelled';
      expect(
        _failure(await storage.authorize(interactive: true)),
        isA<BackupStorageCancelledFailure>(),
      );
      final object = await create(first);

      final sameFolder = await select();
      expect(sameFolder.account.id, first.account.id);
      expect(platform.calls.where((call) => call == 'release'), isEmpty);
      expect(
        _failure(await first.list(mimeType: mimeType)),
        isA<BackupStoragePermissionRevokedFailure>(),
      );

      platform.selection = 'second';
      final second = await select();
      expect(second.account.id, isNot(first.account.id));
      expect(platform.grants, {'second'});
      platform.files[object.name] = bytes;
      expect(
        _failure(await second.delete(object)),
        isA<BackupStorageNotFoundFailure>(),
      );
      expect(platform.files, contains(object.name));
    },
  );

  test(
    'disconnect revokes before a concurrent reselection of the same folder',
    () async {
      final first = await select();
      final release = Completer<void>();
      platform.releaseGate = release;
      final disconnecting = first.disconnect();
      final selecting = storage.authorize(interactive: true);
      await Future<void>.delayed(Duration.zero);
      expect(platform.calls, ['pick', 'release']);
      release.complete();
      ok(await disconnecting);
      final second = ok(await selecting);
      expect(platform.grants, {'first'});
      expect(
        _failure(await first.list(mimeType: mimeType)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      ok(await second.disconnect());
      expect(
        _failure(await storage.authorize(interactive: false)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
    },
  );

  test('an expired operation waiting for the store never runs', () async {
    final session = await select();
    final release = Completer<void>();
    platform.releaseGate = release;
    final expireIoTimers = <void Function()>[];

    await runZoned(
      () async {
        final disconnecting = session.disconnect();
        final listing = session.list(mimeType: mimeType);
        await Future<void>.delayed(Duration.zero);
        expect(platform.calls, ['pick', 'release']);
        expect(expireIoTimers, hasLength(2));

        for (final expire in expireIoTimers) {
          expire();
        }
        expect(_failure(await listing), isA<BackupStorageUnavailableFailure>());
        expect(
          _failure(await disconnecting),
          isA<BackupStorageUnavailableFailure>(),
        );

        release.complete();
        await Future<void>.delayed(Duration.zero);
        expect(platform.calls, ['pick', 'release']);
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (_, parent, zone, duration, callback) {
          final timer = parent.createTimer(zone, duration, callback);
          if (duration == const Duration(seconds: 30)) {
            expireIoTimers.add(() {
              timer.cancel();
              zone.run(callback);
            });
          }
          return timer;
        },
      ),
    );
  });

  test('platform failures map to typed failures', () async {
    final session = await select();
    platform.nextError = 'quotaExceeded';
    expect(
      _failure(
        await session.create(
          name: 'bull-data-one.bip138',
          mimeType: mimeType,
          bytes: bytes,
        ),
      ),
      isA<BackupStorageQuotaExceededFailure>(),
    );
    platform.grants.clear();
    expect(
      _failure(await storage.authorize(interactive: false)),
      isA<BackupStoragePermissionRevokedFailure>(),
    );
    expect(
      _failure(await session.list(mimeType: mimeType)),
      isA<BackupStoragePermissionRevokedFailure>(),
    );
  });
}

BackupStorageFailure _failure<T>(Result<T, BackupStorageFailure> result) =>
    (result as Err<T, BackupStorageFailure>).failure;

final class _Store implements FolderGrantStore {
  String? _state;
  Future<void> _tail = Future<void>.value();

  @override
  Future<T> exclusive<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<String?> read() async => _state;

  @override
  Future<void> write(String? state) async {
    _state = state;
  }
}

final class _FolderPlatform {
  final calls = <String>[];
  final grants = <String>{};
  final _folders = <String, Map<String, Uint8List>>{};
  final _accounts = <String, String>{};
  String selection = 'first';
  String? tokenOverride;
  bool corruptWrites = false;
  String? nextError;
  Completer<void>? releaseGate;

  Map<String, Uint8List> get files => _folders.putIfAbsent(selection, () => {});

  Future<Object?> invoke(MethodCall call) async {
    calls.add(call.method);
    final code = nextError;
    if (code != null) {
      nextError = null;
      throw PlatformException(code: code);
    }
    if (call.method == 'pick') {
      final token = tokenOverride ?? selection;
      grants.add(token);
      _accounts[token] = selection;
      return {'token': token, 'id': selection, 'name': selection};
    }
    final args = call.arguments as Map<Object?, Object?>;
    final token = args['token'] as String;
    if (call.method == 'release') {
      await releaseGate?.future;
      grants.remove(token);
      return null;
    }
    if (!grants.contains(token)) {
      throw PlatformException(code: 'permissionRevoked');
    }
    final account = _accounts[token];
    if (account == null) throw StateError('Missing fake account');
    final files = _folders.putIfAbsent(account, () => {});
    final id = args['id'] as String?;
    switch (call.method) {
      case 'inspect':
        return {'id': account, 'name': account};
      case 'list':
        return [
          for (final name in files.keys) {'id': name, 'name': name},
        ];
      case 'create':
        final name = args['name'] as String;
        files[name] = corruptWrites
            ? Uint8List.fromList([1, 2, 3, 4])
            : args['bytes'] as Uint8List;
        return {'id': name, 'name': name, 'size': files[name]?.length};
      case 'read':
        final bytes = files[id];
        if (bytes == null) throw PlatformException(code: 'notFound');
        if (bytes.length > (args['maxBytes'] as int)) {
          throw PlatformException(code: 'tooLarge');
        }
        return bytes;
      case 'delete':
        if (files.remove(id) == null) throw PlatformException(code: 'notFound');
        return null;
      default:
        throw StateError('Unexpected method');
    }
  }
}
