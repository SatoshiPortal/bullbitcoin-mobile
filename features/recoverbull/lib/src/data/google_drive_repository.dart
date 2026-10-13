import 'mappers/encrypted_vault_mapper.dart';
import 'dart:convert';

import './datasources/google_drive_datasource.dart';
import '../domain/entities/drive_file_metadata.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/google_drive_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Data boundary for Google Drive vault storage. Catches Drive/auth/IO
/// exceptions, logs safe classifications, and returns a [RecoverBullFailure].
final class GoogleDriveRepositoryImpl implements GoogleDriveRepository {
  final LogSink log;
  final GoogleDriveAppDatasource _dataSource;
  Future<void> _queue = Future<void>.value();
  int _accountGeneration = 0;
  bool _disposed = false;

  GoogleDriveRepositoryImpl({
    required this.log,
    required GoogleDriveAppDatasource datasource,
  }) : _dataSource = datasource;

  @override
  Future<Result<Null, RecoverBullFailure>> connect() async {
    return _serialized(() async {
      _accountGeneration++;
      try {
        await _dataSource.connect();
        return const Ok(null);
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.connect.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  @override
  Future<String?> connectSilently() => _serialized(_dataSource.connectSilently);

  @override
  Future<void> disconnect() => _serialized(() async {
    _accountGeneration++;
    await _dataSource.disconnect();
  });

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(GoogleDriveDiscoverySession? session) action,
  ) async {
    final session = await _serialized(() async {
      final account = await _dataSource.connectSilently();
      return account == null
          ? null
          : _Session(this, account, _accountGeneration);
    });
    try {
      return await action(session);
    } finally {
      session?._active = false;
    }
  }

  @override
  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  fetchAllMetadata() async {
    return _serialized(() async {
      try {
        return Ok(await _fetchAllMetadata());
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.fetch_metadata.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchVault(
    String fileId,
  ) async {
    return _serialized(() async {
      try {
        return Ok(EncryptedVaultMapper.parse(await _fetchContent(fileId)));
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.fetch_vault.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  /// Raw file content (not parsed as a vault) — used when exporting a backup
  /// file verbatim to local storage.
  @override
  Future<Result<String, RecoverBullFailure>> fetchRawFile(String fileId) async {
    return _serialized(() async {
      try {
        return Ok(await _fetchContent(fileId));
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.fetch_raw.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  /// Fetches the most recently created vault. (The "pick latest" shaping lives
  /// here, not in the use-case, and an empty Drive surfaces as a failure rather
  /// than the `StateError` `reduce` would throw.)
  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchLatestVault() async {
    return _serialized(() async {
      try {
        final backups = await _fetchAllMetadata();
        if (backups.isEmpty) {
          return const Err(RecoverBullUnexpectedFailure('no drive backups'));
        }
        final latest = backups.reduce(
          (a, b) => a.createdTime.compareTo(b.createdTime) > 0 ? a : b,
        );
        return Ok(EncryptedVaultMapper.parse(await _fetchContent(latest.id)));
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.fetch_latest.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  @override
  Future<Result<Null, RecoverBullFailure>> store(EncryptedVault vault) async {
    final content = EncryptedVaultMapper.fromEntity(vault).toFile();
    return _serialized(() async {
      try {
        await _dataSource.store(content);
        return const Ok(null);
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.store.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  @override
  Future<Result<Null, RecoverBullFailure>> trash(String fileId) async {
    return _serialized(() async {
      try {
        await _dataSource.trash(fileId);
        return const Ok(null);
      } on Exception catch (e, st) {
        log.error(
          'recoverbull.drive.trash.unexpected error_type=${e.runtimeType}',
          trace: st,
        );
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  Future<List<DriveFileMetadata>> _fetchAllMetadata() async {
    final files = await _dataSource.fetchAllMetadata();
    return files.map((file) => file.toEntity()).toList();
  }

  Future<String> _fetchContent(String fileId) async {
    final bytes = await _dataSource.fetchFileContent(fileId);
    return utf8.decode(bytes);
  }

  /// Cancels queued discovery capabilities and closes the owned HTTP client.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _accountGeneration++;
    _dataSource.dispose();
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    if (_disposed) throw StateError('Drive repository is disposed');
    final start = _queue;
    Future<T> run() {
      if (_disposed) throw const _DiscoverySessionExpiredException();
      return action();
    }

    final result = start.then((_) => run(), onError: (_, _) => run());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<T> _withCurrentAccount<T>(
    _Session session,
    Future<T> Function() action,
  ) => _serialized(() async {
    if (!session._active || session._generation != _accountGeneration) {
      throw const _DiscoverySessionExpiredException();
    }
    final account = await _dataSource.connectSilently();
    if (account != session.account ||
        session._generation != _accountGeneration) {
      throw const _DiscoverySessionExpiredException();
    }
    return action();
  });

  Future<List<DriveFileMetadata>> _sessionMetadata(_Session session) async {
    final files = <DriveFileMetadata>[];
    final seenTokens = <String>{};
    String? token;
    while (true) {
      final page = await _withCurrentAccount(
        session,
        () => _dataSource.fetchMetadataPage(token),
      );
      files.addAll(page.files.map((file) => file.toEntity()));
      final next = page.nextPageToken;
      if (next == null || next.isEmpty) return files;
      if (!seenTokens.add(next)) {
        throw const FormatException('Drive pagination repeated a page token');
      }
      token = next;
    }
  }
}

final class _Session implements GoogleDriveDiscoverySession {
  final GoogleDriveRepositoryImpl _repository;
  @override
  final String account;
  final int _generation;
  bool _active = true;

  _Session(this._repository, this.account, this._generation);

  @override
  Future<T> withCurrentAccount<T>(Future<T> Function() action) =>
      _repository._withCurrentAccount(this, action);

  @override
  Future<List<DriveFileMetadata>> fetchAllMetadata() =>
      _repository._sessionMetadata(this);

  @override
  Future<String> fetchRawFile(String fileId) =>
      withCurrentAccount(() => _repository._fetchContent(fileId));
}

final class _DiscoverySessionExpiredException implements Exception {
  const _DiscoverySessionExpiredException();
}
