import 'dart:convert';

import 'package:bb_mobile/core_deprecated/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/drive_file_metadata.dart';

class GoogleDriveRepository {
  final _dataSource = GoogleDriveAppDatasource();

  GoogleDriveRepository();

  Future<void> connect() async => await _dataSource.connect();

  Future<void> disconnect() => _dataSource.disconnect();

  Future<List<DriveFileMetadata>> fetchAllMetadata() async {
    final files = await _dataSource.fetchAllMetadata();
    return files.map((file) => file.toEntity()).toList();
  }

  Future<String> fetchFileContent(String fileId) async {
    final bytes = await _dataSource.fetchFileContent(fileId);
    return utf8.decode(bytes);
  }

  Future<void> store(String content) async {
    await _dataSource.store(content);
  }

  Future<void> trash(String fileId) async {
    await _dataSource.trash(fileId);
  }
}
