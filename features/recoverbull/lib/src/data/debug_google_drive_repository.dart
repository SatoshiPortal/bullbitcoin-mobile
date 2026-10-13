import 'package:flutter/foundation.dart' show kDebugMode;
import 'mappers/encrypted_vault_mapper.dart';
import 'dart:convert';

import 'package:primitives/primitives.dart';

import '../domain/entities/drive_file_metadata.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/google_drive_repository.dart';

/// An in-memory Drive containing deterministic, non-secret vault fixtures.
/// This class is intentionally usable only from debug composition.
final class DebugGoogleDriveRepository implements GoogleDriveRepository {
  final String accountEmail;
  final Map<String, _DebugDriveFile> _files = {};
  int _nextId = 0;
  bool _connected = false;
  Future<void> _queue = Future<void>.value();
  int _accountGeneration = 0;

  DebugGoogleDriveRepository({
    this.accountEmail = 'recoverbull.debug@example.invalid',
  }) {
    for (var i = 0; i < 3; i++) {
      final vault = _fixture(i);
      final id = 'debug-file-$i';
      _files[id] = _DebugDriveFile(
        content: EncryptedVaultMapper.fromEntity(vault).toFile(),
        createdAt: vault.createdAt.toUtc(),
      );
    }
    _nextId = _files.length;
  }

  @override
  Future<Result<Null, RecoverBullFailure>> connect() => _serialized(() async {
    _accountGeneration++;
    _connected = true;
    return const Ok(null);
  });

  @override
  Future<String?> connectSilently() => _serialized(() async {
    _connected = true;
    return accountEmail;
  });

  @override
  Future<void> disconnect() => _serialized(() async {
    _accountGeneration++;
    _connected = false;
  });

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(GoogleDriveDiscoverySession? session) action,
  ) async {
    final session = await _serialized(() async {
      _connected = true;
      return _DebugSession(this, accountEmail, _accountGeneration);
    });
    try {
      return await action(session);
    } finally {
      session._active = false;
    }
  }

  @override
  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  fetchAllMetadata() => _serialized(_fetchAllMetadataUnlocked);

  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  _fetchAllMetadataUnlocked() async {
    if (!_connected) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    return Ok([
      for (final entry in _files.entries)
        DriveFileMetadata(
          id: entry.key,
          name: EncryptedVaultMapper.parse(entry.value.content).filename,
          createdTime: entry.value.createdAt,
          modifiedTime: null,
        ),
    ]);
  }

  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchVault(
    String fileId,
  ) => _serialized(() => _fetchVaultUnlocked(fileId));

  Future<Result<EncryptedVault, RecoverBullFailure>> _fetchVaultUnlocked(
    String fileId,
  ) async {
    if (!_connected) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    final content = _files[fileId]?.content;
    if (content == null) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    return Ok(EncryptedVaultMapper.parse(content));
  }

  @override
  Future<Result<String, RecoverBullFailure>> fetchRawFile(String fileId) =>
      _serialized(() => _fetchRawFileUnlocked(fileId));

  Future<Result<String, RecoverBullFailure>> _fetchRawFileUnlocked(
    String fileId,
  ) async {
    if (!_connected) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    final content = _files[fileId]?.content;
    return content == null
        ? const Err(RecoverBullUnexpectedFailure('Drive operation failed'))
        : Ok(content);
  }

  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchLatestVault() =>
      _serialized(_fetchLatestVaultUnlocked);

  Future<Result<EncryptedVault, RecoverBullFailure>>
  _fetchLatestVaultUnlocked() async {
    if (!_connected) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    if (_files.isEmpty) {
      return const Err(RecoverBullUnexpectedFailure('no drive backups'));
    }
    final file = _files.values.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    return Ok(EncryptedVaultMapper.parse(file.content));
  }

  @override
  Future<Result<Null, RecoverBullFailure>> store(EncryptedVault vault) =>
      _serialized(() => _storeUnlocked(vault));

  Future<Result<Null, RecoverBullFailure>> _storeUnlocked(
    EncryptedVault vault,
  ) async {
    if (!_connected) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    try {
      _files['debug-file-${_nextId++}'] = _DebugDriveFile(
        content: EncryptedVaultMapper.fromEntity(vault).toFile(),
        createdAt: vault.createdAt.toUtc(),
      );
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  @override
  Future<Result<Null, RecoverBullFailure>> trash(String fileId) =>
      _serialized(() => _trashUnlocked(fileId));

  Future<Result<Null, RecoverBullFailure>> _trashUnlocked(String fileId) async {
    if (!_connected) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    if (_files.remove(fileId) == null) {
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
    return const Ok(null);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final start = _queue;
    final result = start.then((_) => action(), onError: (_, _) => action());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<T> _withCurrentAccount<T>(
    _DebugSession session,
    Future<T> Function() action,
  ) => _serialized(() async {
    if (!session._active ||
        !_connected ||
        session._generation != _accountGeneration) {
      throw const _DebugDiscoverySessionExpiredException();
    }
    return action();
  });

  static EncryptedVault _fixture(int index) {
    final id = List<int>.generate(32, (i) => (i + index) & 0xff);
    final salt = List<int>.generate(16, (i) => (i * 3 + index) & 0xff);
    final bytes = List<int>.generate(64, (i) => (i + index * 7) & 0xff);
    final raw = jsonEncode({
      'version': 1,
      'created_at': DateTime.utc(2026, 1, index + 1).millisecondsSinceEpoch,
      'id': id.map((v) => v.toRadixString(16).padLeft(2, '0')).join(),
      'salt': salt.map((v) => v.toRadixString(16).padLeft(2, '0')).join(),
      'ciphertext': base64Encode(bytes),
      'path': "m/83696968'/0'/0'",
    });
    return EncryptedVaultMapper.parse(raw);
  }
}

final class _DebugSession implements GoogleDriveDiscoverySession {
  final DebugGoogleDriveRepository repository;
  @override
  final String account;
  final int _generation;
  bool _active = true;

  _DebugSession(this.repository, this.account, this._generation);

  @override
  Future<T> withCurrentAccount<T>(Future<T> Function() action) =>
      repository._withCurrentAccount(this, action);

  @override
  Future<List<DriveFileMetadata>> fetchAllMetadata() async {
    final result = await withCurrentAccount(
      repository._fetchAllMetadataUnlocked,
    );
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw Exception('Drive metadata unavailable'),
    };
  }

  @override
  Future<String> fetchRawFile(String fileId) async {
    final result = await withCurrentAccount(
      () => repository._fetchRawFileUnlocked(fileId),
    );
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw Exception('Drive content unavailable'),
    };
  }
}

final class _DebugDiscoverySessionExpiredException implements Exception {
  const _DebugDiscoverySessionExpiredException();
}

final class _DebugDriveFile {
  final String content;
  final DateTime createdAt;

  const _DebugDriveFile({required this.content, required this.createdAt});
}

GoogleDriveRepository selectGoogleDriveRepository({
  required GoogleDriveRepository production,
  bool fakeEnabled = const bool.fromEnvironment('RECOVERBULL_FAKE_DRIVE'),
  bool debugMode = kDebugMode,
}) {
  if (fakeEnabled && !debugMode) {
    throw StateError('RECOVERBULL_FAKE_DRIVE is debug-only');
  }
  return fakeEnabled ? DebugGoogleDriveRepository() : production;
}
