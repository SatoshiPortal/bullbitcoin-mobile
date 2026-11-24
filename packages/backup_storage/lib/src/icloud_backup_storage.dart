import 'dart:async';

import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';

import 'backup_storage.dart';
import 'backup_storage_failure.dart';

/// Persistent app-local connection state shared by foreground and background.
abstract interface class ICloudConnectionStore {
  /// Returns a persisted grant revision. Odd revisions are disconnected.
  ///
  /// Return 0 for a container with no saved state. Reads must reflect writes
  /// from other engines and isolates.
  Future<int> readRevision(String containerId);

  /// Atomically replaces [expected] with [revision]. Returns false on conflict.
  ///
  /// Store revisions atomically and durably. A disconnect advances to an odd
  /// revision, and an interactive reconnect advances to the next even revision.
  Future<bool> compareAndSet(
    String containerId, {
    required int expected,
    required int revision,
  });
}

/// Uses OS-managed iCloud Documents access. Disconnect revokes this app
/// capability through [ICloudConnectionStore], leaving OS access in place.
final class ICloudBackupStorage implements BackupStorage {
  static const _channel = MethodChannel(
    'com.bullbitcoin.backup_storage/icloud',
  );
  static const _timeout = Duration(seconds: 20);
  static const _extension = '.bip138';

  final String containerId;
  final ICloudConnectionStore _connections;

  ICloudBackupStorage({required this.containerId, required this._connections});

  @override
  BackupDestination get destination => BackupDestination.iCloud;

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) => _run((remaining) async {
    final revision = await _connections.readRevision(containerId);
    if (revision.isOdd && !interactive) {
      throw const _AuthorizationRequired();
    }
    final accountId = await _invoke<String>('authorize', remaining);
    final nextRevision = revision.isOdd ? revision + 1 : revision;
    if (revision != nextRevision) {
      remaining();
      final saved = await _connections.compareAndSet(
        containerId,
        expected: revision,
        revision: nextRevision,
      );
      if (!saved) throw const _AuthorizationRequired();
    }
    if (await _connections.readRevision(containerId) != nextRevision) {
      throw const _AuthorizationRequired();
    }
    return _ICloudStorageSession(
      this,
      StorageAccount(id: accountId),
      nextRevision,
    );
  });

  /// Reads the container without advancing the connection revision: a
  /// disconnected container stays disconnected, and a connected one keeps its
  /// grant.
  @override
  Future<Result<StorageReadSession, BackupStorageFailure>>
  authorizeForDiscovery() => _run((remaining) async {
    final accountId = await _invoke<String>('authorize', remaining);
    return _ICloudDiscoverySession(this, StorageAccount(id: accountId));
  });

  Future<T> _invoke<T>(
    String method,
    Duration Function() remaining, [
    Map<String, Object> arguments = const {},
  ]) async {
    final result = await _channel.invokeMethod<T>(method, {
      'container': containerId,
      'timeoutMs': remaining().inMilliseconds,
      ...arguments,
    });
    if (result == null) throw const FormatException();
    return result;
  }

  Future<Result<T, BackupStorageFailure>> _run<T>(
    Future<T> Function(Duration Function()) action,
  ) async {
    final clock = Stopwatch()..start();
    Duration remaining() {
      final left = _timeout - clock.elapsed;
      if (left.inMilliseconds <= 0) throw TimeoutException('iCloud operation');
      return left;
    }

    try {
      return Ok(await action(remaining).timeout(_timeout));
    } on _AuthorizationRequired {
      return const Err(BackupStorageAuthorizationRequiredFailure());
    } on TimeoutException {
      return const Err(BackupStorageUnavailableFailure());
    } on MissingPluginException {
      return const Err(BackupStorageUnavailableFailure(retryable: false));
    } on PlatformException catch (error) {
      return Err(switch (error.code) {
        'authorizationRequired' =>
          const BackupStorageAuthorizationRequiredFailure(),
        'quotaExceeded' => const BackupStorageQuotaExceededFailure(),
        'notFound' => const BackupStorageNotFoundFailure(),
        'tooLarge' => const BackupStorageTooLargeFailure(),
        'unavailable' => const BackupStorageUnavailableFailure(),
        'cancelled' => const BackupStorageCancelledFailure(),
        _ => const BackupStorageUnexpectedFailure(),
      });
    } on Exception {
      return const Err(BackupStorageUnexpectedFailure());
    }
  }

  static bool _isBackupName(String name) =>
      name.length > _extension.length &&
      name.endsWith(_extension) &&
      !name.startsWith('.') &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !name.contains('\u0000');

  static StoredObject _object(Object? value) {
    if (value case {'name': final String name, 'uploaded': final bool uploaded}
        when _isBackupName(name)) {
      final size = value['size'];
      final modified = value['modifiedMs'];
      final created = value['createdMs'];
      return StoredObject(
        id: name,
        name: name,
        size: size is int && size >= 0 ? size : null,
        createdAt: created is int
            ? DateTime.fromMillisecondsSinceEpoch(created, isUtc: true)
            : null,
        modifiedAt: modified is int
            ? DateTime.fromMillisecondsSinceEpoch(modified, isUtc: true)
            : null,
        durability: uploaded ? Durability.durable : Durability.pending,
      );
    }
    throw const FormatException();
  }
}

/// Reads one iCloud container. A full session also enforces the persisted
/// connection revision; a discovery view holds no persisted grant.
abstract base class _ICloudView implements StorageReadSession {
  final ICloudBackupStorage _storage;
  @override
  final StorageAccount account;

  _ICloudView(this._storage, this.account);

  Future<Result<T, BackupStorageFailure>> _operate<T>(
    Future<T> Function(Duration Function()) action,
  );

  Future<T> _invoke<T>(
    String method,
    Duration Function() remaining, [
    Map<String, Object> arguments = const {},
  ]) => _storage._invoke<T>(method, remaining, {
    'account': account.id,
    ...arguments,
  });

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) => _operate((remaining) async {
    final values = await _invoke<List<Object?>>('list', remaining, {
      'prefix': ?namePrefix,
    });
    return [
      for (final object in values.map(ICloudBackupStorage._object))
        if (namePrefix == null || object.name.startsWith(namePrefix)) object,
    ];
  });

  @override
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  }) => _operate((remaining) async {
    final bytes = await _invoke<Uint8List>('read', remaining, {
      'name': _objectName(object),
      'maxBytes': maxBytes,
      'knownSize': ?object.size,
    });
    if (bytes.length > maxBytes) throw PlatformException(code: 'tooLarge');
    return bytes;
  });

  String _objectName(StoredObject object) {
    if (object.id != object.name ||
        !ICloudBackupStorage._isBackupName(object.id)) {
      throw PlatformException(code: 'notFound');
    }
    return object.id;
  }
}

final class _ICloudStorageSession extends _ICloudView
    implements StorageSession {
  final int _revision;
  bool _disposed = false;

  _ICloudStorageSession(super._storage, super.account, this._revision);

  Future<void> _checkGrant() async {
    if (_disposed ||
        await _storage._connections.readRevision(_storage.containerId) !=
            _revision ||
        _disposed) {
      throw const _AuthorizationRequired();
    }
  }

  @override
  Future<Result<T, BackupStorageFailure>> _operate<T>(
    Future<T> Function(Duration Function()) action,
  ) => _storage._run((remaining) async {
    await _checkGrant();
    try {
      final result = await action(remaining);
      await _checkGrant();
      return result;
    } on PlatformException catch (error) {
      if (error.code == 'authorizationRequired') dispose();
      rethrow;
    }
  });

  @override
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) => _operate((remaining) async {
    if (!ICloudBackupStorage._isBackupName(name)) {
      throw const FormatException();
    }
    return ICloudBackupStorage._object(
      await _invoke<Map<Object?, Object?>>('create', remaining, {
        'name': name,
        'bytes': bytes,
      }),
    );
  });

  @override
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object) =>
      _operate((remaining) async {
        await _invoke<bool>('delete', remaining, {'name': _objectName(object)});
      });

  @override
  Future<Result<void, BackupStorageFailure>> disconnect() =>
      _storage._run((remaining) async {
        await _checkGrant();
        await _invoke<bool>('checkAccount', remaining);
        remaining();
        if (_disposed) throw const _AuthorizationRequired();
        final saved = await _storage._connections.compareAndSet(
          _storage.containerId,
          expected: _revision,
          revision: _revision + 1,
        );
        if (!saved) throw const _AuthorizationRequired();
        dispose();
      });

  @override
  Future<void> close() async {
    dispose();
  }

  @override
  void dispose() => _disposed = true;
}

final class _ICloudDiscoverySession extends _ICloudView {
  bool _disposed = false;

  _ICloudDiscoverySession(super._storage, super.account);

  @override
  Future<Result<T, BackupStorageFailure>> _operate<T>(
    Future<T> Function(Duration Function()) action,
  ) => _storage._run((remaining) async {
    if (_disposed) throw const _AuthorizationRequired();
    final result = await action(remaining);
    if (_disposed) throw const _AuthorizationRequired();
    return result;
  });

  @override
  Future<void> close() async {
    dispose();
  }

  void dispose() => _disposed = true;
}

final class _AuthorizationRequired implements Exception {
  const _AuthorizationRequired();
}
