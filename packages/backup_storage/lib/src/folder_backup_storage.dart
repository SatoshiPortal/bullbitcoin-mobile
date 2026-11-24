import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';

import 'backup_storage.dart';
import 'backup_storage_failure.dart';

/// Dedicated persistent state for the selected folder and write receipts.
/// Treat the serialized value as opaque and do not log or sync it.
abstract interface class FolderGrantStore {
  /// Serializes operations across all instances, isolates and engines sharing
  /// this store. The lock must be released when the process dies.
  Future<T> exclusive<T>(Future<T> Function() operation);

  Future<String?> read();

  /// Atomically replaces the stored value. Null deletes the grant and receipts.
  Future<void> write(String? state);
}

final class FolderBackupStorage implements BackupStorage {
  static const _channel = MethodChannel(
    'com.bullbitcoin.backup_storage/folder',
  );
  static const _ioDeadline = Duration(seconds: 30);
  static const _pickerDeadline = Duration(minutes: 2);

  final FolderGrantStore _store;

  FolderBackupStorage(this._store);

  @override
  BackupDestination get destination => BackupDestination.folder;

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) => _run(interactive ? _pickerDeadline : _ioDeadline, (expired) async {
    final previous = await _readGrant();
    if (expired()) throw TimeoutException('Folder authorization expired');
    if (!interactive) {
      if (previous == null) throw _authorizationRequired;
      final info = await _invokeMap('inspect', previous.token);
      if (info['id'] != previous.accountId) throw _revoked;
      return _FolderSession(this, previous, info['name'] as String?);
    }

    final pick = await _invokeMap('pick', null);
    final token = pick['token'] as String;
    final accountId = pick['id'] as String;
    final grant = _FolderGrant(
      token,
      accountId,
      _newRevision(),
      previous?.accountId == accountId ? previous?.receipts ?? {} : {},
    );
    try {
      if (expired()) throw TimeoutException('Folder selection expired');
      await _store.write(grant.encode());
    } on Exception {
      if (previous?.token != token) await _release(token);
      rethrow;
    }

    final oldToken = previous?.token;
    if (oldToken != null && oldToken != token) await _release(oldToken);
    return _FolderSession(this, grant, pick['name'] as String?);
  });

  @override
  Future<Result<StorageReadSession, BackupStorageFailure>>
  authorizeForDiscovery() => _run(_pickerDeadline, (expired) async {
    final previous = await _readGrant();
    if (expired()) throw TimeoutException('Folder authorization expired');
    final pick = await _invokeMap('pick', null);
    final grant = _FolderGrant(
      pick['token'] as String,
      pick['id'] as String,
      _newRevision(),
      const {},
    );
    // The store, the receipts and the configured grant are untouched: this
    // pick only names the folder this discovery reads.
    final retain = grant.token == previous?.token;
    if (expired()) {
      if (!retain) await _release(grant.token);
      throw TimeoutException('Folder selection expired');
    }
    return _FolderDiscoverySession(
      this,
      grant,
      pick['name'] as String?,
      retain: retain,
    );
  });

  Future<_FolderGrant?> _readGrant() async {
    final state = await _store.read();
    return state == null ? null : _FolderGrant.decode(state);
  }

  Future<void> _release(String token) async {
    try {
      await _channel.invokeMethod<void>('release', {'token': token});
    } on PlatformException catch (error) {
      if (error.code != 'permissionRevoked') rethrow;
    }
  }

  Future<Result<T, BackupStorageFailure>> _run<T>(
    Duration deadline,
    Future<T> Function(bool Function() expired) operation,
  ) async {
    final elapsed = Stopwatch()..start();
    var timedOut = false;
    bool expired() => timedOut || elapsed.elapsed >= deadline;
    try {
      final result = await _store
          .exclusive(() {
            if (expired()) throw TimeoutException('Folder operation expired');
            return operation(expired);
          })
          .timeout(
            deadline,
            onTimeout: () {
              timedOut = true;
              throw TimeoutException('Folder operation expired');
            },
          );
      return Ok(result);
    } on _FolderFailure catch (error) {
      return Err(error.failure);
    } on TimeoutException {
      return Err(const BackupStorageUnavailableFailure());
    } on MissingPluginException {
      return Err(const BackupStorageUnavailableFailure(retryable: false));
    } on PlatformException catch (error) {
      return Err(switch (error.code) {
        'authorizationRequired' =>
          const BackupStorageAuthorizationRequiredFailure(),
        'cancelled' => const BackupStorageCancelledFailure(),
        'permissionRevoked' => const BackupStoragePermissionRevokedFailure(),
        'quotaExceeded' => const BackupStorageQuotaExceededFailure(),
        'notFound' => const BackupStorageNotFoundFailure(),
        'tooLarge' => const BackupStorageTooLargeFailure(),
        'unavailable' => const BackupStorageUnavailableFailure(),
        _ => const BackupStorageUnexpectedFailure(),
      });
    } on Exception {
      return Err(const BackupStorageUnexpectedFailure());
    }
  }

  static String _newRevision() {
    final random = Random.secure();
    return base64Url.encode(List.generate(16, (_) => random.nextInt(256)));
  }
}

/// Shared read capabilities of one folder grant. A discovery view holds a
/// temporary grant; a session holds the configured one.
abstract base class _FolderView implements StorageReadSession {
  static const _maxBackupBytes = 4 * 1024 * 1024;

  final FolderBackupStorage _storage;
  final _FolderGrant _selection;
  @override
  final StorageAccount account;
  bool _disposed = false;

  _FolderView(this._storage, this._selection, String? name)
    : account = StorageAccount(
        id: sha256.convert(utf8.encode(_selection.accountId)).toString(),
        displayName: name,
      );

  /// Drops this view. A discovery view cannot read or list afterwards.
  void dispose() => _disposed = true;

  @override
  Future<Result<Uint8List, BackupStorageFailure>> read(
    StoredObject object, {
    required int maxBytes,
  }) => _run((grant, _) => _read(grant, _nativeId(object), maxBytes));

  Future<Result<T, BackupStorageFailure>> _run<T>(
    Future<T> Function(_FolderGrant grant, bool Function() expired) operation,
  );

  Future<Uint8List> _read(_FolderGrant grant, String id, int maxBytes) async {
    if (maxBytes < 0) {
      throw const _FolderFailure(BackupStorageTooLargeFailure());
    }
    final bytes = await FolderBackupStorage._channel.invokeMethod<Uint8List>(
      'read',
      {
        'token': grant.token,
        'accountId': grant.accountId,
        'id': id,
        'maxBytes': maxBytes,
      },
    );
    if (bytes == null) throw const FormatException();
    if (bytes.length > maxBytes) {
      throw const _FolderFailure(BackupStorageTooLargeFailure());
    }
    return bytes;
  }

  String get _idPrefix => '${account.id}:';

  String _nativeId(StoredObject object) {
    final prefix = _idPrefix;
    if (!object.id.startsWith(prefix)) {
      throw const _FolderFailure(BackupStorageNotFoundFailure());
    }
    return object.id.substring(prefix.length);
  }

  StoredObject _object(Map<Object?, Object?> info, Durability durability) =>
      StoredObject(
        id: '$_idPrefix${info['id'] as String}',
        name: info['name'] as String,
        size: info['size'] as int?,
        modifiedAt: switch (info['modifiedMs']) {
          final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
          _ => null,
        },
        durability: durability,
      );
}

final class _FolderSession extends _FolderView implements StorageSession {
  static const _extension = '.bip138';

  _FolderSession(super._storage, super._selection, super.name);

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) => _run((grant, expired) async {
    final entries = await FolderBackupStorage._channel
        .invokeListMethod<Object?>('list', {
          'token': grant.token,
          'accountId': grant.accountId,
        });
    if (entries == null) throw const FormatException();
    final result = <StoredObject>[];
    for (final entry in entries.cast<Map<Object?, Object?>>()) {
      final name = entry['name'] as String;
      if (!name.endsWith(_extension) ||
          (namePrefix != null && !name.startsWith(namePrefix))) {
        continue;
      }

      final receipt = grant.receipts[entry['id']];
      var durability = Durability.pending;
      if (receipt != null) {
        if (expired()) throw TimeoutException('Folder listing expired');
        try {
          final bytes = await _read(
            grant,
            entry['id'] as String,
            _FolderView._maxBackupBytes,
          );
          if (sha256.convert(bytes).toString() == receipt) {
            durability = Durability.durable;
          }
        } on PlatformException catch (error) {
          if (error.code == 'notFound') continue;
          if (error.code != 'tooLarge') rethrow;
        }
      }
      result.add(_object(entry, durability));
    }
    return result;
  });

  @override
  Future<Result<StoredObject, BackupStorageFailure>> create({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final expected = bytes.length <= _FolderView._maxBackupBytes
        ? Uint8List.fromList(bytes)
        : null;
    return _run((grant, expired) async {
      if (expected == null) {
        throw const _FolderFailure(BackupStorageTooLargeFailure());
      }
      final entry = await _invokeMap('create', grant.token, {
        'accountId': grant.accountId,
        'name': name,
        'mimeType': mimeType,
        'bytes': expected,
      });
      if (expired()) throw TimeoutException('Folder write expired');
      final id = entry['id'] as String;
      final actual = await _read(grant, id, expected.length);
      if (!listEquals(actual, expected)) {
        throw const _FolderFailure(BackupStorageUnavailableFailure());
      }
      if (expired()) throw TimeoutException('Folder verification expired');
      grant.receipts[id] = sha256.convert(expected).toString();
      await _storage._store.write(grant.encode());
      return _object(entry, Durability.durable);
    });
  }

  @override
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object) =>
      _run((grant, _) async {
        final id = _nativeId(object);
        await FolderBackupStorage._channel.invokeMethod<void>('delete', {
          'token': grant.token,
          'accountId': grant.accountId,
          'id': id,
        });
        if (grant.receipts.remove(id) != null) {
          await _storage._store.write(grant.encode());
        }
      });

  @override
  Future<Result<void, BackupStorageFailure>> disconnect() =>
      _run((grant, _) async {
        await _storage._release(grant.token);
        await _storage._store.write(null);
        dispose();
      });

  @override
  Future<void> close() async {
    dispose();
  }

  @override
  Future<Result<T, BackupStorageFailure>> _run<T>(
    Future<T> Function(_FolderGrant grant, bool Function() expired) operation,
  ) => _storage._run(FolderBackupStorage._ioDeadline, (expired) async {
    if (_disposed) throw _authorizationRequired;
    final current = await _storage._readGrant();
    if (current == null || current.revision != _selection.revision) {
      throw _revoked;
    }
    if (_disposed) throw _authorizationRequired;
    if (expired()) throw TimeoutException('Folder operation expired');
    return operation(current, expired);
  });
}

/// Reads a folder the user picked for restore discovery. The pick is never
/// written to the grant store, so the configured destination and its receipts
/// stay exactly as they were.
final class _FolderDiscoverySession extends _FolderView {
  static const _extension = '.bip138';

  /// True when the picked folder is already the configured one: closing must
  /// then leave its grant in place.
  final bool _retain;
  bool _closed = false;

  _FolderDiscoverySession(
    super._storage,
    super._selection,
    super.name, {
    required this._retain,
  });

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) => _run((grant, expired) async {
    final entries = await FolderBackupStorage._channel
        .invokeListMethod<Object?>('list', {
          'token': grant.token,
          'accountId': grant.accountId,
        });
    if (entries == null) throw const FormatException();
    final result = <StoredObject>[];
    for (final entry in entries.cast<Map<Object?, Object?>>()) {
      final name = entry['name'] as String;
      if (!name.endsWith(_extension) ||
          (namePrefix != null && !name.startsWith(namePrefix))) {
        continue;
      }
      if (expired()) throw TimeoutException('Folder listing expired');
      // No receipts: discovery never proves the durability of a foreign copy.
      result.add(_object(entry, Durability.pending));
    }
    return result;
  });

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    dispose();
    // Releasing a temporary pick is best effort: the configured grant and the
    // store are never touched here, so a failure leaves nothing inconsistent.
    await _storage._run(FolderBackupStorage._ioDeadline, (_) async {
      if (_retain) return;
      // Another configure may have adopted this exact folder meanwhile.
      final configured = await _storage._readGrant();
      if (configured?.token == _selection.token) return;
      await _storage._release(_selection.token);
    });
  }

  @override
  Future<Result<T, BackupStorageFailure>> _run<T>(
    Future<T> Function(_FolderGrant grant, bool Function() expired) operation,
  ) => _storage._run(FolderBackupStorage._ioDeadline, (expired) async {
    if (_disposed) throw _authorizationRequired;
    if (expired()) throw TimeoutException('Folder operation expired');
    return operation(_selection, expired);
  });
}

final class _FolderGrant {
  final String token;
  final String accountId;
  final String revision;
  final Map<String, String> receipts;

  _FolderGrant(this.token, this.accountId, this.revision, this.receipts);

  factory _FolderGrant.decode(String state) {
    final data = jsonDecode(state) as Map<String, dynamic>;
    return _FolderGrant(
      data['token'] as String,
      data['accountId'] as String,
      data['revision'] as String,
      Map<String, String>.from(data['receipts'] as Map),
    );
  }

  String encode() => jsonEncode({
    'token': token,
    'accountId': accountId,
    'revision': revision,
    'receipts': receipts,
  });
}

final class _FolderFailure implements Exception {
  final BackupStorageFailure failure;

  const _FolderFailure(this.failure);
}

const _authorizationRequired = _FolderFailure(
  BackupStorageAuthorizationRequiredFailure(),
);
const _revoked = _FolderFailure(BackupStoragePermissionRevokedFailure());

Future<Map<Object?, Object?>> _invokeMap(
  String method,
  String? token, [
  Map<String, Object?> args = const {},
]) async {
  final result = await FolderBackupStorage._channel
      .invokeMapMethod<Object?, Object?>(method, {'token': token, ...args});
  if (result == null) throw const FormatException();
  return result;
}
