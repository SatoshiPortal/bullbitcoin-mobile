import 'dart:async';

import 'package:backup_storage/backup_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/storage_contract.dart';

const _channel = MethodChannel('com.bullbitcoin.backup_storage/icloud');
const _container = 'iCloud.com.example.test';
const _mime = 'application/vnd.bull.backup+bip138';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _ConnectionStore connections;
  late _ICloudChannel platform;
  setUp(() {
    connections = _ConnectionStore();
    platform = _ICloudChannel();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      platform.handle,
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  ICloudBackupStorage storage({String containerId = _container}) =>
      ICloudBackupStorage(containerId: containerId, connections: connections);

  Future<StorageSession> authorize() async =>
      ok(await storage().authorize(interactive: false));

  group('iCloud storage contract', () {
    storageContract(() => storage(), matchByExtension: true);
  });

  test(
    'container is injected and empty iCloud identity requires authorization',
    () async {
      platform.account = null;
      final result = await storage(containerId: 'iCloud.com.example.other')
          .authorize(interactive: true);

      expect(
        _failure(result),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      expect(platform.lastArguments['container'], 'iCloud.com.example.other');
      expect(platform.lastArguments['timeoutMs'], inInclusiveRange(1, 20000));
      expect(storage().destination, BackupDestination.iCloud);
    },
  );

  test(
    'account switch fences all operations and invalidates the old session',
    () async {
      final session = await authorize();
      final staleDisconnect = await authorize();
      final object = ok(
        await session.create(
          name: 'bull-data-1.bip138',
          mimeType: _mime,
          bytes: Uint8List.fromList([1]),
        ),
      );
      platform.account = 'different-account';
      final failure = _failure(await session.delete(object));
      expect(failure, isA<BackupStorageAuthorizationRequiredFailure>());
      expect(platform.files, contains(object.name));
      expect(
        _failure(await staleDisconnect.disconnect()),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );

      platform.account = session.account.id;
      expect(
        _failure(await session.list(mimeType: _mime)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      platform.account = 'different-account';
      expect((await authorize()).account.id, isNot(session.account.id));
    },
  );

  test(
    'disconnect persists across instances and old grants stay revoked',
    () async {
      final first = await authorize();
      final otherInstance = await authorize();
      ok(await first.disconnect());

      expect(
        _failure(await storage().authorize(interactive: false)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      expect(
        _failure(await otherInstance.list(mimeType: _mime)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      final otherContainer = storage(containerId: 'iCloud.com.example.other');
      ok(await otherContainer.authorize(interactive: false));

      ok(await storage().authorize(interactive: true));
      final restored = await authorize();
      expect(restored.account.id, first.account.id);
      expect(ok(await restored.list(mimeType: _mime)), isEmpty);
      expect(
        _failure(await otherInstance.list(mimeType: _mime)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
    },
  );

  test(
    'a disconnected grant survives a failed interactive reconnect',
    () async {
      final session = await authorize();
      ok(await session.disconnect());
      platform.account = null;
      expect(
        _failure(await storage().authorize(interactive: true)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
      platform.account = 'first-account';
      expect(
        _failure(await storage().authorize(interactive: false)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
    },
  );

  test(
    'relist refreshes durability and the read delegates eviction and cap',
    () async {
      final session = await authorize();
      final object = ok(
        await session.create(
          name: 'bull-data-1.bip138',
          mimeType: _mime,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
      expect(object.durability, Durability.pending);

      final file = platform.files[object.id];
      expect(file, isNotNull);
      if (file == null) throw StateError('Missing mock file');
      file
        ..uploaded = true
        ..evicted = true;

      final listed = ok(await session.list(mimeType: _mime)).single;
      expect(listed.durability, Durability.durable);
      expect(ok(await session.read(listed, maxBytes: 3)), [1, 2, 3]);
      expect(file.evicted, isFalse);
      expect(platform.lastArguments['maxBytes'], 3);

      final unknownSize = StoredObject(
        id: listed.id,
        name: listed.name,
        durability: listed.durability,
      );
      expect(
        _failure(await session.read(unknownSize, maxBytes: 2)),
        isA<BackupStorageTooLargeFailure>(),
      );

      platform.ignoreReadLimit = true;
      expect(
        _failure(await session.read(unknownSize, maxBytes: 2)),
        isA<BackupStorageTooLargeFailure>(),
      );
    },
  );

  test(
    'translated native failures carry only the storage failure type',
    () async {
      final session = await authorize();
      final failures = <String, Matcher>{
        'quotaExceeded': isA<BackupStorageQuotaExceededFailure>(),
        'notFound': isA<BackupStorageNotFoundFailure>(),
        'unavailable': isA<BackupStorageUnavailableFailure>().having(
          (failure) => failure.retryable,
          'retryable',
          isTrue,
        ),
        'cancelled': isA<BackupStorageCancelledFailure>(),
        'unexpected': isA<BackupStorageUnexpectedFailure>(),
      };
      for (final entry in failures.entries) {
        platform.failureCode = entry.key;
        expect(_failure(await session.list(mimeType: _mime)), entry.value);
      }
    },
  );

  test(
    'discovery reads a disconnected container without reconnecting it',
    () async {
      final session = await authorize();
      final object = ok(
        await session.create(
          name: 'bull-data-1.bip138',
          mimeType: _mime,
          bytes: Uint8List.fromList([1]),
        ),
      );
      ok(await session.disconnect());
      expect(await connections.readRevision(_container) % 2, 1);

      final view = ok(await storage().authorizeForDiscovery());
      expect(view.account.id, 'first-account');
      expect(ok(await view.list(mimeType: _mime)).single.id, object.id);
      expect(await connections.readRevision(_container) % 2, 1);

      await view.close();
      expect(await connections.readRevision(_container) % 2, 1);
      expect(
        _failure(await storage().authorize(interactive: false)),
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
    },
  );

  test('rejects path components before issuing a file operation', () async {
    final session = await authorize();
    final previous = platform.lastArguments;
    final result = await session.create(
      name: '../outside.bip138',
      mimeType: _mime,
      bytes: Uint8List(0),
    );
    expect(_failure(result), isA<BackupStorageUnexpectedFailure>());
    expect(platform.lastArguments, same(previous));
  });

  testWidgets('a stalled native request has a fixed deadline', (tester) async {
    final session = await tester.runAsync(authorize);
    if (session == null) throw StateError('Could not authorize mock iCloud');
    final pending = Completer<Object?>();
    platform.pendingList = pending;
    final result = session.list(mimeType: _mime);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(_failure(await result), isA<BackupStorageUnavailableFailure>());
    pending.complete(<Object?>[]);
    await tester.pump();
  });
}

BackupStorageFailure _failure<T>(Result<T, BackupStorageFailure> result) =>
    switch (result) {
      Err(:final failure) => failure,
      Ok() => throw StateError('Expected a storage failure'),
    };

final class _ConnectionStore implements ICloudConnectionStore {
  final Map<String, int> _revisions = {};

  @override
  Future<int> readRevision(String containerId) async =>
      _revisions[containerId] ?? 0;

  @override
  Future<bool> compareAndSet(
    String containerId, {
    required int expected,
    required int revision,
  }) async {
    if ((_revisions[containerId] ?? 0) != expected) return false;
    _revisions[containerId] = revision;
    return true;
  }
}

final class _CloudFile {
  final Uint8List bytes;
  bool uploaded = false;
  bool evicted = false;

  _CloudFile(this.bytes);

  Map<String, Object> describe(String name) => {
    'name': name,
    'uploaded': uploaded,
    'size': bytes.length,
  };
}

final class _ICloudChannel {
  final Map<String, _CloudFile> files = {};
  String? account = 'first-account';
  String? failureCode;
  Completer<Object?>? pendingList;
  bool ignoreReadLimit = false;
  Map<Object?, Object?> lastArguments = {};

  Future<Object?> handle(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>;
    lastArguments = arguments;
    final identity = account;
    if (identity == null ||
        (call.method != 'authorize' && arguments['account'] != identity)) {
      throw PlatformException(code: 'authorizationRequired');
    }
    final code = failureCode;
    if (code != null) throw PlatformException(code: code);
    switch (call.method) {
      case 'authorize':
        return identity;
      case 'checkAccount':
        return true;
      case 'list':
        final pending = pendingList;
        if (pending != null) return pending.future;
        return [
          for (final entry in files.entries) entry.value.describe(entry.key),
        ];
      case 'create':
        final name = arguments['name'] as String;
        final file = _CloudFile(arguments['bytes'] as Uint8List);
        files[name] = file;
        return file.describe(name);
      case 'read':
        final file = files[arguments['name']];
        if (file == null) throw PlatformException(code: 'notFound');
        final maximum = arguments['maxBytes'] as int;
        if (!ignoreReadLimit && file.bytes.length > maximum) {
          throw PlatformException(code: 'tooLarge');
        }
        file.evicted = false;
        return file.bytes;
      case 'delete':
        return files.remove(arguments['name']) != null;
      default:
        throw MissingPluginException();
    }
  }
}
