import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'backup_storage_failure.dart';

enum BackupDestination { googleDrive, iCloud, folder }

abstract interface class BackupStorage {
  BackupDestination get destination;

  @useResult
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  });
}

abstract interface class StorageSession {
  StorageAccount get account;

  /// Exhausts all pages. Prefix matching is literal, not a backend query.
  @useResult
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  });

  @useResult
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  });

  @useResult
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  });

  @useResult
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object);

  /// Revokes the grant; disposal alone never revokes it.
  @useResult
  Future<Result<void, BackupStorageFailure>> disconnect();

  void dispose();
}

final class StorageAccount {
  final String id;
  final String? displayName;

  const StorageAccount({required this.id, this.displayName});
}

final class StoredObject {
  final String id;
  final String name;
  final int? size;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final String? md5;
  final Durability durability;

  const StoredObject({
    required this.id,
    required this.name,
    this.size,
    this.createdAt,
    this.modifiedAt,
    this.md5,
    required this.durability,
  });
}

/// Backend-relative acknowledgement, refreshed by listing before pruning.
enum Durability { pending, durable }
