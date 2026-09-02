import 'dart:convert';

import './datasources/google_drive_datasource.dart';
import '../domain/entities/drive_file_metadata.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/google_drive_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Data boundary for Google Drive vault storage. Catches Drive/auth/IO
/// exceptions, logs the raw reason, and returns a [RecoverBullFailure].
final class GoogleDriveRepositoryImpl implements GoogleDriveRepository {
  final LogSink log;
  final GoogleDriveAppDatasource _dataSource;
  Future<void> _queue = Future<void>.value();

  GoogleDriveRepositoryImpl({
    required this.log,
    required GoogleDriveAppDatasource datasource,
  }) : _dataSource = datasource;

  @override
  Future<Result<Null, RecoverBullFailure>> connect() async {
    return _serialized(() async {
      try {
        await _dataSource.connect();
        return const Ok(null);
      } catch (e, st) {
        log.error('drive connect failed', error: e, trace: st);
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  @override
  Future<String?> connectSilently() => _serialized(_dataSource.connectSilently);

  @override
  Future<void> disconnect() => _serialized(_dataSource.disconnect);

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(GoogleDriveDiscoverySession? session) action,
  ) => _serialized(() async {
    final account = await _dataSource.connectSilently();
    if (account == null) return action(null);
    return action(_Session(this, account));
  });

  @override
  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  fetchAllMetadata() async {
    return _serialized(() async {
      try {
        return Ok(await _fetchAllMetadata());
      } catch (e, st) {
        log.error('drive fetchAllMetadata failed', error: e, trace: st);
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
        return Ok(EncryptedVault(file: await _fetchContent(fileId)));
      } catch (e, st) {
        log.error('drive fetchVault failed', error: e, trace: st);
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
      } catch (e, st) {
        log.error('drive fetchRawFile failed', error: e, trace: st);
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
        return Ok(EncryptedVault(file: await _fetchContent(latest.id)));
      } catch (e, st) {
        log.error('drive fetchLatestVault failed', error: e, trace: st);
        return const Err(
          RecoverBullUnexpectedFailure('Drive operation failed'),
        );
      }
    });
  }

  @override
  Future<Result<Null, RecoverBullFailure>> store(String content) async {
    return _serialized(() async {
      try {
        await _dataSource.store(content);
        return const Ok(null);
      } catch (e, st) {
        log.error('drive store failed', error: e, trace: st);
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
      } catch (e, st) {
        log.error('drive trash failed', error: e, trace: st);
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

  Future<T> _serialized<T>(Future<T> Function() action) {
    final start = _queue;
    final result = start.then((_) => action(), onError: (_, _) => action());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<List<DriveFileMetadata>> _sessionMetadata() => _fetchAllMetadata();
}

final class _Session implements GoogleDriveDiscoverySession {
  final GoogleDriveRepositoryImpl _repository;
  @override
  final String account;

  const _Session(this._repository, this.account);

  @override
  Future<List<DriveFileMetadata>> fetchAllMetadata() =>
      _repository._sessionMetadata();

  @override
  Future<String> fetchRawFile(String fileId) =>
      _repository._fetchContent(fileId);
}
