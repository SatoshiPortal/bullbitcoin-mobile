import 'dart:typed_data';

import 'package:backup_storage/backup_storage.dart';
import 'package:primitives/primitives.dart';

final class InMemoryStorage implements BackupStorage {
  @override
  BackupDestination get destination => BackupDestination.folder;

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) async => Ok(_Session());
}

final class _Session implements StorageSession {
  final _objects =
      <String, ({StoredObject object, String mime, Uint8List bytes})>{};
  bool _active = true;
  int _nextId = 0;

  @override
  StorageAccount get account => const StorageAccount(id: 'memory');

  Future<Result<T, BackupStorageFailure>> _run<T>(
    Result<T, BackupStorageFailure> Function() action,
  ) async => _active
      ? action()
      : const Err(BackupStorageAuthorizationRequiredFailure());

  @override
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) => _run(() {
    final object = StoredObject(
      id: '${_nextId++}',
      name: name,
      size: bytes.length,
      durability: Durability.durable,
    );
    _objects[object.id] = (
      object: object,
      mime: mimeType,
      bytes: Uint8List.fromList(bytes),
    );
    return Ok(object);
  });

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) => _run(
    () => Ok(
      _objects.values
          .where(
            (item) =>
                item.mime == mimeType &&
                (namePrefix == null || item.object.name.startsWith(namePrefix)),
          )
          .map((item) => item.object)
          .toList(),
    ),
  );

  @override
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  }) => _run(() {
    final stored = _objects[object.id];
    if (stored == null) return const Err(BackupStorageNotFoundFailure());
    if (stored.bytes.length > maxBytes) {
      return const Err(BackupStorageTooLargeFailure());
    }
    return Ok(Uint8List.fromList(stored.bytes));
  });

  @override
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object) =>
      _run(() {
        _objects.remove(object.id);
        return const Ok(null);
      });

  @override
  Future<Result<void, BackupStorageFailure>> disconnect() async {
    dispose();
    return const Ok(null);
  }

  @override
  void dispose() => _active = false;
}
