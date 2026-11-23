import 'dart:typed_data';

import 'package:backup_storage/backup_storage.dart';
import 'package:primitives/primitives.dart';

final class MemoryBackupStorage implements BackupStorage {
  final Map<String, Map<StoredObject, Uint8List>> accounts = {};
  final List<String> deleted = [];
  final Set<String> unavailableReads = {};
  final Durability durability;

  String accountId = 'a';
  int created = 0;
  bool failAfterCreate = false;
  bool corruptRead = false;

  @override
  final BackupDestination destination;

  MemoryBackupStorage({
    this.destination = BackupDestination.googleDrive,
    this.durability = Durability.durable,
  });

  Map<StoredObject, Uint8List> get objects =>
      accounts.putIfAbsent(accountId, () => {});

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) async => Ok(_Session(this, accountId, objects));
}

final class _Session implements StorageSession {
  final MemoryBackupStorage storage;
  final Map<StoredObject, Uint8List> objects;

  @override
  final StorageAccount account;

  _Session(this.storage, String accountId, this.objects)
    : account = StorageAccount(id: accountId);

  @override
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final object = StoredObject(
      id: '${++storage.created}',
      name: name,
      size: bytes.length,
      createdAt: DateTime.utc(2026).add(Duration(seconds: storage.created)),
      durability: storage.durability,
    );
    objects[object] = Uint8List.fromList(bytes);
    if (storage.failAfterCreate) {
      return const Err(BackupStorageUnavailableFailure());
    }
    return Ok(object);
  }

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) async => Ok(objects.keys.toList());

  @override
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  }) async {
    if (storage.unavailableReads.contains(object.id)) {
      return const Err(BackupStorageUnavailableFailure());
    }
    final bytes = objects[object];
    if (bytes == null) return const Err(BackupStorageNotFoundFailure());
    if (bytes.length > maxBytes) {
      return const Err(BackupStorageTooLargeFailure());
    }
    return Ok(storage.corruptRead ? Uint8List(1) : Uint8List.fromList(bytes));
  }

  @override
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object) async {
    storage.deleted.add(object.id);
    objects.remove(object);
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupStorageFailure>> disconnect() async =>
      const Ok(null);

  @override
  void dispose() {}
}
