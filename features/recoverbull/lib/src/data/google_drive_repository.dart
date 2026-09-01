import 'dart:convert';

import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Data boundary for Google Drive vault storage. Catches Drive/auth/IO
/// exceptions, logs the raw reason, and returns a [RecoverBullFailure].
class GoogleDriveRepository {
  final LogSink log;
  final GoogleDriveAppDatasource _dataSource;

  GoogleDriveRepository({
    required this.log,
    required GoogleDriveAppDatasource datasource,
  }) : _dataSource = datasource;

  Future<Result<Null, RecoverBullFailure>> connect() async {
    try {
      await _dataSource.connect();
      return const Ok(null);
    } catch (e, st) {
      log.error('drive connect failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  Future<void> disconnect() => _dataSource.disconnect();

  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  fetchAllMetadata() async {
    try {
      return Ok(await _fetchAllMetadata());
    } catch (e, st) {
      log.error('drive fetchAllMetadata failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  Future<Result<EncryptedVault, RecoverBullFailure>> fetchVault(
    String fileId,
  ) async {
    try {
      return Ok(EncryptedVault(file: await _fetchContent(fileId)));
    } catch (e, st) {
      log.error('drive fetchVault failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  /// Raw file content (not parsed as a vault) — used when exporting a backup
  /// file verbatim to local storage.
  Future<Result<String, RecoverBullFailure>> fetchRawFile(String fileId) async {
    try {
      return Ok(await _fetchContent(fileId));
    } catch (e, st) {
      log.error('drive fetchRawFile failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  /// Fetches the most recently created vault. (The "pick latest" shaping lives
  /// here, not in the use-case, and an empty Drive surfaces as a failure rather
  /// than the `StateError` `reduce` would throw.)
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchLatestVault() async {
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
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  Future<Result<Null, RecoverBullFailure>> store(String content) async {
    try {
      await _dataSource.store(content);
      return const Ok(null);
    } catch (e, st) {
      log.error('drive store failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  Future<Result<Null, RecoverBullFailure>> trash(String fileId) async {
    try {
      await _dataSource.trash(fileId);
      return const Ok(null);
    } catch (e, st) {
      log.error('drive trash failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('Drive operation failed'));
    }
  }

  Future<List<DriveFileMetadata>> _fetchAllMetadata() async {
    final files = await _dataSource.fetchAllMetadata();
    return files.map((file) => file.toEntity()).toList();
  }

  Future<String> _fetchContent(String fileId) async {
    final bytes = await _dataSource.fetchFileContent(fileId);
    return utf8.decode(bytes);
  }
}
