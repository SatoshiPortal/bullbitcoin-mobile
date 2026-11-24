import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'backup_storage_failure.dart';

enum BackupDestination { googleDrive, iCloud, folder }

abstract interface class BackupStorage {
  BackupDestination get destination;

  /// Opens the configured destination grant.
  ///
  /// Interactive authorization replaces the configured grant and releases the
  /// previous one, so only an explicit configuration action may request it.
  @useResult
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  });

  /// Opens a temporary view of a destination to find restore files.
  ///
  /// It may ask the user to choose a location, but it never persists that
  /// choice and never replaces or releases the configured grant. It is exposed
  /// as read-only; close it with [StorageReadSession.close].
  @useResult
  Future<Result<StorageReadSession, BackupStorageFailure>>
  authorizeForDiscovery();
}

/// Reads one destination. A discovery view is temporary; a [StorageSession]
/// also writes through the same base capability.
abstract interface class StorageReadSession {
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

  /// Releases this view. It never revokes the configured grant: a discovery
  /// view drops only the temporary authorization it obtained, and a full
  /// session releases local resources with [StorageSession.dispose].
  Future<void> close();
}

abstract interface class StorageSession implements StorageReadSession {
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
