import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/models/drive_file_model.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';

class GoogleDriveRepository {
  final GoogleDriveAppDatasource _dataSource;

  GoogleDriveRepository(this._dataSource);

  Future<void> connect() async => await _dataSource.connect();

  Future<void> disconnect() => _dataSource.disconnect();

  Future<void> connectSilently() async => await _dataSource.connectSilently();

  Future<List<DriveFile>> fetchBackupFiles() async {
    final files = await _dataSource.fetchAll();
    return files
        .map((file) => DriveFileModel.fromDriveFile(file).toDomain())
        .toList();
  }

  Future<String> fetchBackupContent(String fileId) async {
    final bytes = await _dataSource.fetchContent(fileId);
    return utf8.decode(bytes);
  }

  Future<void> storeBackup(String content) async {
    await _dataSource.store(content);
  }

  Future<void> trashBackup(String path) async {
    await _dataSource.trash(path);
  }
}
