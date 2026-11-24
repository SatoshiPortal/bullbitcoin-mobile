import 'dart:typed_data';

import 'package:backup_storage/backup_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

T ok<T>(Result<T, BackupStorageFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

/// Every backend can reuse this suite with an isolated, empty storage per test.
/// Native backends can supply a fake platform; Drive supplies mocked HTTP.
void storageContract(
  BackupStorage Function() createStorage, {
  bool matchByExtension = false,
}) {
  final prefix = matchByExtension ? "contract-'" : "contract-'\\";
  final extension = matchByExtension ? '.bip138' : '.bin';
  final mimeType = matchByExtension
      ? 'application/vnd.bull.backup+bip138'
      : 'application/octet-stream';
  late StorageSession session;
  setUp(() async {
    session = ok(await createStorage().authorize(interactive: false));
  });
  tearDown(() => session.dispose());

  test('byte round trip, literal prefix listing and deletion', () async {
    expect(session.account.id, isNotEmpty);
    final bytes = Uint8List.fromList([0, 255, 1, 13, 10]);
    final object = ok(
      await session.create(
        name: '$prefix$extension',
        mimeType: mimeType,
        bytes: bytes,
      ),
    );
    expect(object.id, isNotEmpty);
    expect(ok(await session.read(object, maxBytes: 5)), bytes);
    final listed = ok(
      await session.list(mimeType: mimeType, namePrefix: prefix),
    );
    expect(listed.map((item) => item.id), contains(object.id));
    final otherMime = ok(await session.list(mimeType: 'application/json'));
    if (matchByExtension) {
      expect(otherMime.map((item) => item.id), contains(object.id));
    } else {
      expect(otherMime, isEmpty);
    }
    expect(
      ok(await session.list(mimeType: mimeType, namePrefix: 'absent-')),
      isEmpty,
    );
    ok(await session.delete(object));
    expect(ok(await session.list(mimeType: mimeType)), isEmpty);
    expect(
      await session.read(object, maxBytes: 5),
      isA<Err<Uint8List, BackupStorageFailure>>(),
    );
  });

  test('read cap rejects oversized bytes', () async {
    final object = ok(
      await session.create(
        name: 'large$extension',
        mimeType: mimeType,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
    final result = await session.read(object, maxBytes: 2);
    expect(
      (result as Err<Uint8List, BackupStorageFailure>).failure,
      isA<BackupStorageTooLargeFailure>(),
    );
  });

  test('dispose is idempotent and invalidates the capability', () async {
    session.dispose();
    session.dispose();
    final result = await session.list(mimeType: 'application/json');
    expect(
      (result as Err<List<StoredObject>, BackupStorageFailure>).failure,
      isA<BackupStorageAuthorizationRequiredFailure>(),
    );
  });

  test('disconnect invalidates the capability', () async {
    ok(await session.disconnect());
    final result = await session.list(mimeType: 'application/json');
    expect(
      (result as Err<List<StoredObject>, BackupStorageFailure>).failure,
      isA<BackupStorageAuthorizationRequiredFailure>(),
    );
  });
}
