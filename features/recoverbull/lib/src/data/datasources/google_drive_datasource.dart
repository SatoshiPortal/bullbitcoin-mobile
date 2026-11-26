import 'dart:convert';

import 'package:backup_storage/backup_storage.dart';
import 'package:primitives/primitives.dart';

import '../mappers/encrypted_vault_mapper.dart';
import '../models/drive_file_metadata_model.dart';

class GoogleDriveAppDatasource {
  static const _mimeType = 'application/json';
  static const _maxVaultBytes = 2 * 1024 * 1024;

  final BackupStorage _storage;
  StorageSession? _session;
  int _requestGeneration = 0;
  bool _disposed = false;

  GoogleDriveAppDatasource({BackupStorage? storage})
    : _storage = storage ?? GoogleDriveBackupStorage();

  Future<void> connect() async {
    await _connect(interactive: true);
  }

  Future<String?> connectSilently() => _connect(interactive: false);

  Future<String?> _connect({required bool interactive}) async {
    _checkNotDisposed();
    final generation = ++_requestGeneration;
    final result = await _storage.authorize(interactive: interactive);
    if (generation != _requestGeneration) {
      if (result case Ok(:final value)) value.dispose();
      if (interactive) throw const _DriveOperationException();
      return null;
    }

    switch (result) {
      case Ok(:final value):
        _replaceSession(value);
        return value.account.id;
      case Err():
        // A failed discovery probe leaves the foreground capability available
        // for the same account. Storage itself fences any account change.
        if (!interactive) return null;
        _replaceSession(null);
        throw const _DriveOperationException();
    }
  }

  Future<void> disconnect() async {
    _checkNotDisposed();
    final generation = ++_requestGeneration;
    final result = await _storage.authorize(interactive: false);
    if (generation != _requestGeneration) {
      if (result case Ok(:final value)) value.dispose();
      throw const _DriveOperationException();
    }
    _replaceSession(null);

    switch (result) {
      case Ok(:final value):
        try {
          _value(await value.disconnect());
        } finally {
          value.dispose();
        }
      case Err(failure: BackupStorageAuthorizationRequiredFailure()):
        return;
      case Err():
        throw const _DriveOperationException();
    }
  }

  /// Releases the session without revoking the user's Drive grant.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _requestGeneration++;
    _replaceSession(null);
  }

  Future<List<DriveFileMetadataModel>> fetchAllMetadata() async {
    final objects = _value(await _connectedSession.list(mimeType: _mimeType));
    return objects.map(DriveFileMetadataModel.fromStoredObject).toList();
  }

  Future<List<int>> fetchFileContent(String fileId) async {
    final result = await _connectedSession.read(
      _objectReference(fileId),
      maxBytes: _maxVaultBytes,
    );
    if (result case Err(failure: BackupStorageTooLargeFailure())) {
      throw const FormatException('Drive vault exceeds size limit');
    }
    return _value(result);
  }

  Future<void> trash(String fileId) async {
    _value(await _connectedSession.delete(_objectReference(fileId)));
  }

  Future<void> store(String content) async {
    final session = _connectedSession;
    final vault = EncryptedVaultMapper.parse(content);
    final jsonVault = EncryptedVaultMapper.fromEntity(vault).toFile();
    _value(
      await session.create(
        name: vault.filename,
        mimeType: _mimeType,
        bytes: utf8.encode(jsonVault),
      ),
    );
  }

  StorageSession get _connectedSession {
    _checkNotDisposed();
    final session = _session;
    if (session == null) throw const _DriveOperationException();
    return session;
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Drive datasource is disposed');
  }

  void _replaceSession(StorageSession? session) {
    final previous = _session;
    _session = session;
    if (!identical(previous, session)) previous?.dispose();
  }

  // Drive reads and deletes use only the opaque ID, including after a refresh.
  StoredObject _objectReference(String id) =>
      StoredObject(id: id, name: '', durability: Durability.durable);

  T _value<T>(Result<T, BackupStorageFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => throw const _DriveOperationException(),
  };
}

final class _DriveOperationException implements Exception {
  const _DriveOperationException();
}
