import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Data boundary for Google Drive vault storage. Catches Drive/auth/IO
/// exceptions, logs the raw reason, and returns a [RecoverBullCoreFailure].
class GoogleDriveRepository {
  final GoogleDriveAppDatasource _dataSource;

  GoogleDriveRepository({required GoogleDriveAppDatasource datasource})
    : _dataSource = datasource;

  Future<Result<Null, RecoverBullCoreFailure>> connect() async {
    try {
      await _dataSource.connect();
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'drive connect failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<void> disconnect() => _dataSource.disconnect();

  Future<Result<List<DriveFileMetadata>, RecoverBullCoreFailure>>
  fetchAllMetadata() async {
    try {
      return Ok(await _fetchAllMetadata());
    } catch (e, st) {
      log.severe(message: 'drive fetchAllMetadata failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<Result<EncryptedVault, RecoverBullCoreFailure>> fetchVault(
    String fileId,
  ) async {
    try {
      return Ok(EncryptedVault(file: await _fetchContent(fileId)));
    } catch (e, st) {
      log.severe(message: 'drive fetchVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// Raw file content (not parsed as a vault) — used when exporting a backup
  /// file verbatim to local storage.
  Future<Result<String, RecoverBullCoreFailure>> fetchRawFile(
    String fileId,
  ) async {
    try {
      return Ok(await _fetchContent(fileId));
    } catch (e, st) {
      log.severe(message: 'drive fetchRawFile failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// Fetches the most recently created vault. (The "pick latest" shaping lives
  /// here, not in the use-case, and an empty Drive surfaces as a failure rather
  /// than the `StateError` `reduce` would throw.)
  Future<Result<EncryptedVault, RecoverBullCoreFailure>>
  fetchLatestVault() async {
    try {
      final backups = await _fetchAllMetadata();
      if (backups.isEmpty) {
        return const Err(RecoverBullUnexpectedCoreFailure('no drive backups'));
      }
      final latest = backups.reduce(
        (a, b) => a.createdTime.compareTo(b.createdTime) > 0 ? a : b,
      );
      return Ok(EncryptedVault(file: await _fetchContent(latest.id)));
    } catch (e, st) {
      log.severe(message: 'drive fetchLatestVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<Result<Null, RecoverBullCoreFailure>> store(String content) async {
    try {
      await _dataSource.store(content);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'drive store failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<Result<Null, RecoverBullCoreFailure>> trash(String fileId) async {
    try {
      await _dataSource.trash(fileId);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'drive trash failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
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
