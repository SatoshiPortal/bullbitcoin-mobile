import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/models/drive_file_model.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/google_drive_repository.dart';

class GoogleDriveRepositoryImpl implements GoogleDriveRepository {
  final GoogleDriveAppDatasource _dataSource;

  GoogleDriveRepositoryImpl(this._dataSource);

  @override
  Future<void> connect() async {
    await _dataSource.connect();
  }

  @override
  Future<void> disconnect() => _dataSource.disconnect();

  @override
  Future<List<DriveFile>> fetchBackupFiles() async {
    final files = await _dataSource.fetchAll();
    return files
        .map((file) => DriveFileModel.fromDriveFile(file).toDomain())
        .toList();
  }

  @override
  Future<String> fetchBackupContent(String fileId) async {
    final bytes = await _dataSource.fetchContent(fileId);
    return utf8.decode(bytes);
  }

  @override
  Future<void> storeBackup(String content) async {
    await _dataSource.store(content);
  }

  @override
  Future<void> trashBackup(String path) async {
    await _dataSource.trash(path);
  }
}
