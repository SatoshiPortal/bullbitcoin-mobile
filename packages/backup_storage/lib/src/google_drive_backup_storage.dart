import 'dart:async';
import 'dart:typed_data';

import 'package:google_drive/google_drive.dart';
import 'package:primitives/primitives.dart';

import 'backup_storage.dart';
import 'backup_storage_failure.dart';

/// App-private Drive storage. Each session owns its transport.
final class GoogleDriveBackupStorage implements BackupStorage {
  static const _deadline = Duration(seconds: 60);
  final GoogleDrive Function() _open;

  GoogleDriveBackupStorage({GoogleDrive Function()? open})
    : _open = open ?? GoogleDrive.open;

  @override
  BackupDestination get destination => BackupDestination.googleDrive;

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) async {
    final drive = _open();
    var acquired = false;
    try {
      final Result<String?, GoogleDriveFailure> authorization;
      if (interactive) {
        authorization = (await drive.connect().timeout(_deadline))
            .map((_) => drive.account);
      } else {
        authorization = await drive.connectSilently().timeout(_deadline);
      }
      if (authorization case Err(:final failure)) return Err(_map(failure));
      final email = drive.account;
      if (email == null) {
        return const Err(BackupStorageAuthorizationRequiredFailure());
      }
      acquired = true;
      return Ok(_DriveSession(drive, email));
    } on TimeoutException {
      return const Err(BackupStorageUnavailableFailure());
    } finally {
      if (!acquired) drive.dispose();
    }
  }

  /// Signs in to read another account's app folder. The sign-in owner is
  /// shared, so this never revokes a grant and never rewrites the backup
  /// selection: a different account only takes effect through an explicit
  /// configuration.
  @override
  Future<Result<StorageReadSession, BackupStorageFailure>>
  authorizeForDiscovery() => authorize(interactive: true);
}

final class _DriveSession implements StorageSession {
  final GoogleDrive _drive;
  @override
  final StorageAccount account;

  _DriveSession(this._drive, String email)
    : account = StorageAccount(id: email);

  Future<Result<T, BackupStorageFailure>> _run<T>(
    Future<Result<T, GoogleDriveFailure>> Function() operation,
  ) async {
    if (_drive.account != account.id) {
      return const Err(BackupStorageAuthorizationRequiredFailure());
    }
    try {
      final result = await operation().timeout(
        GoogleDriveBackupStorage._deadline,
      );
      if (_drive.account != account.id) {
        return const Err(BackupStorageAuthorizationRequiredFailure());
      }
      return result.mapErr(_map);
    } on TimeoutException {
      dispose();
      return const Err(BackupStorageUnavailableFailure());
    }
  }

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) => _run(
    () async => (await _drive.listFiles(mimeType: mimeType)).map(
      (files) => [
        for (final file in files)
          if (namePrefix == null || file.name.startsWith(namePrefix))
            _object(file),
      ],
    ),
  );

  @override
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  }) {
    if (maxBytes < 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    return _run(() async {
      if ((object.size ?? 0) > maxBytes) {
        return const Err(GoogleDriveTooLargeFailure());
      }
      return (await _drive.readFile(
        fileId: object.id,
        maxBytes: maxBytes,
      )).map(Uint8List.fromList);
    });
  }

  @override
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) => _run(
    () async => (await _drive.createFile(
      filename: name,
      bytes: bytes,
      mimeType: mimeType,
    )).map(_object),
  );

  @override
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object) =>
      _run(() => _drive.deleteFile(object.id));

  @override
  Future<Result<void, BackupStorageFailure>> disconnect() async {
    try {
      if (_drive.account != account.id) {
        return const Err(BackupStorageAuthorizationRequiredFailure());
      }
      return (await _drive.revokeAccess().timeout(
        GoogleDriveBackupStorage._deadline,
      )).mapErr(_map);
    } on TimeoutException {
      return const Err(BackupStorageUnavailableFailure());
    } finally {
      dispose();
    }
  }

  @override
  Future<void> close() async {
    dispose();
  }

  @override
  void dispose() => _drive.dispose();
}

StoredObject _object(GoogleDriveFileMetadata file) => StoredObject(
  id: file.id,
  name: file.name,
  size: file.size,
  md5: file.md5,
  createdAt: file.createdTime,
  modifiedAt: file.modifiedTime,
  durability: Durability.durable,
);

BackupStorageFailure _map(GoogleDriveFailure failure) => switch (failure) {
  GoogleDriveAuthorizationRequiredFailure() || GoogleDriveDisposedFailure() =>
    const BackupStorageAuthorizationRequiredFailure(),
  GoogleDriveCancelledFailure() => const BackupStorageCancelledFailure(),
  GoogleDrivePermissionRevokedFailure() =>
    const BackupStoragePermissionRevokedFailure(),
  GoogleDriveQuotaExceededFailure() =>
    const BackupStorageQuotaExceededFailure(),
  GoogleDriveNotFoundFailure() => const BackupStorageNotFoundFailure(),
  GoogleDriveTooLargeFailure() => const BackupStorageTooLargeFailure(),
  GoogleDriveUnavailableFailure() => const BackupStorageUnavailableFailure(),
  GoogleDriveInvalidResponseFailure() => const BackupStorageUnexpectedFailure(),
};
